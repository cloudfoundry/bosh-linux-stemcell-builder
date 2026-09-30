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

# Override the upstream AppArmor sysctl restrictions that ship in
# /usr/lib/sysctl.d/10-apparmor.conf on Ubuntu 26.04+.  When systemd-sysctl
# runs inside a privileged container it writes to the *host* /proc/sys,
# resetting kernel.apparmor_restrict_unprivileged_userns to 1 and breaking
# any host process that relies on unprivileged user namespaces.
if [ -f "$chroot/usr/lib/sysctl.d/10-apparmor.conf" ]; then
  cat > "$chroot/etc/sysctl.d/20-disable-apparmor-restrict.conf" <<SYSCTL
kernel.apparmor_restrict_unprivileged_userns = 0
kernel.apparmor_restrict_unprivileged_unconfined = 0
SYSCTL
  chmod 0644 "$chroot/etc/sysctl.d/20-disable-apparmor-restrict.conf"
fi

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

# nvmf-autoconnect has no function in warden containers and fails on startup.
run_in_chroot "$chroot" "systemctl mask nvmf-autoconnect.service"

# systemd-udevd has no function in containerised environments.
run_in_chroot "$chroot" "systemctl mask systemd-udevd.service"

# Audit rule changes need the initial PID namespace (audit_netlink_ok() in
# kernel/audit.c returns -EPERM otherwise), so audit-rules.service can never
# succeed in a container and would sit permanently failed. Skipped by condition
# rather than masked so the stemcell still loads the rules if booted on a VM.
# /etc/audit/audit.rules is left intact for the STIG/CIS content checks, and
# auditd only Wants= this unit so it still starts.
mkdir -p "$chroot/etc/systemd/system/audit-rules.service.d"
cat > "$chroot/etc/systemd/system/audit-rules.service.d/warden-skip-in-container.conf" <<'UNIT'
[Unit]
ConditionVirtualization=!container
UNIT

# These images ship no /etc/netplan, so netplan-configure has nothing to
# generate, and its ExecStartPost runs `udevadm control --reload` against the
# systemd-udevd masked above.
mkdir -p "$chroot/etc/systemd/system/netplan-configure.service.d"
cat > "$chroot/etc/systemd/system/netplan-configure.service.d/warden-skip-in-container.conf" <<'UNIT'
[Unit]
ConditionVirtualization=!container
UNIT

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
  logrotate
)

for service in "${rosetta_services[@]}"; do
  mkdir -p "$chroot/etc/systemd/system/${service}.service.d"
  cp "$assets_dir/rosetta-compat.conf" "$chroot/etc/systemd/system/${service}.service.d/rosetta-compat.conf"
done

# mask units which fail under Rosetta and are not needed in a container image
warden_masked_units=(
  systemd-udevd.service
  chrony.service
  systemd-binfmt.service
)

for unit in "${warden_masked_units[@]}"; do
  run_in_chroot "$chroot" "systemctl mask ${unit}"
done
