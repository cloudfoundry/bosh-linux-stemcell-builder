#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Explicit make the mount point for bind-mount
# Otherwise using none ubuntu host will fail creating vm
mkdir -p $chroot/warden-cpi-dev

# Auditd cannot capture events within a container
sed -i 's/^local_events = yes$/local_events = no/g' $chroot/etc/audit/auditd.conf

# As containers have less to startup, some services are restarted very quickly and can hit the systemd
# restart limit of 5 restarts in 5 seconds
sed -i 's/^#DefaultStartLimitBurst=5$/DefaultStartLimitBurst=500/g' $chroot/etc/systemd/system.conf

cat > $chroot/var/vcap/bosh/bin/restart_networking <<EOF
#!/bin/bash

echo "skip network restart: network is already preconfigured"
EOF
chmod +x $chroot/var/vcap/bosh/bin/restart_networking

# Configure go agent specifically for warden
cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "UseDefaultTmpDir": true,
      "UsePreformattedPersistentDisk": true,
      "BindMountPersistentDisk": true,
      "SkipDiskSetup": true,
      "ServiceManager": "systemd"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "File",
          "SettingsPath": "/var/vcap/bosh/warden-cpi-agent-env.json"
        }
      ]
    }
  }
}
JSON

# Rosetta x86_64 emulation compatibility for Apple Silicon Macs
#
# When running warden stemcells under Rosetta emulation on Apple Silicon,
# several systemd services fail because their security hardening features
# (MemoryDenyWriteExecute, SystemCallFilter, etc.) conflict with Rosetta's
# JIT compilation which requires writable+executable memory.
#
# We create systemd drop-in overrides to disable these security features.
# This is acceptable for warden stemcells since they run in containerized
# environments where the host provides security isolation.

rosetta_services=(
  systemd-journald
  systemd-resolved
  systemd-networkd
  systemd-logind
  systemd-timesyncd
  auditd
)

for service in "${rosetta_services[@]}"; do
  mkdir -p "$chroot/etc/systemd/system/${service}.service.d"
  cp "$assets_dir/rosetta-compat.conf" "$chroot/etc/systemd/system/${service}.service.d/rosetta-compat.conf"
done

# Some services are not compatible with running in a container,
# so we mask them to prevent systemd from trying to start them and fail.
masked_services=(
  systemd-binfmt
)
masked_service_units="${masked_services[*]/%/.service}"

echo "base_warden: masking service units: ${masked_service_units}"
run_in_chroot "$chroot" "systemctl mask ${masked_service_units}"

echo "base_warden: service units kept (not masked):"
run_in_chroot "$chroot" "systemctl list-unit-files --state=enabled,static --type=service --no-legend | awk '{print \$1}'"
