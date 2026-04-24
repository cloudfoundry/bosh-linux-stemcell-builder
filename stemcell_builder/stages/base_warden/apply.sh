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
