#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Explicit make the mount point for bind-mount
# Otherwise using none ubuntu host will fail creating vm
mkdir -p $chroot/warden-cpi-dev

# Run system services via runit and replace /usr/sbin/service with a script which call runit
mkdir -p $chroot/etc/sv/
cp -a $assets_dir/runit/{ssh,rsyslog,cron} $chroot/etc/sv/

run_in_chroot $chroot "
chmod +x /etc/sv/{ssh,rsyslog,cron}/run
ln -s /etc/sv/{ssh,rsyslog,cron} /etc/service/
"

# Remove systemd setting from rsyslog as warden doesn't use systemd
run_in_chroot $chroot "
sed -i '/^\\\$SystemLogSocketName /d' /etc/rsyslog.conf
"

# Pending for disk_quota
#run_in_chroot $chroot "
#ln -s /proc/self/mounts /etc/mtab
#"

# unshare is used to launch upstart as PID 1, in tests
# upstart does not run in normal bosh-lite containers
unshare_binary=$chroot/var/vcap/bosh/bin/unshare
cp -f $assets_dir/unshare $unshare_binary
chmod +x $unshare_binary
chown root:root $unshare_binary

# Replace /usr/sbin/service with a script which calls runit
run_in_chroot $chroot "
dpkg-divert --local --rename --add /usr/sbin/service
"

cp -f $assets_dir/service $chroot/usr/sbin/service

run_in_chroot $chroot "
chmod +x /usr/sbin/service
"

cat > $chroot/var/vcap/bosh/bin/bosh-start-logging-and-auditing <<BASH
#!/bin/bash
# "service auditd start" because there is no upstart in containers
BASH

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
      "UseMonitIptablesFirewall": true
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

# Mask systemd-binfmt.service which fails under Rosetta emulation
run_in_chroot "$chroot" "systemctl mask systemd-binfmt.service"

# Trim non-essential systemd units from the boot sequence.
#
# When the Docker CPI runs a warden stemcell with `exec /sbin/init`, full stock
# systemd comes up and its units contend with the monit-managed bpm jobs in the
# BOSH director container (symptom: the postgres role is never created and
# bosh/0 never converges). The Docker CPI used to strip these units at
# container-create time, but that allow-list prune was removed in
# cloudfoundry/bosh-docker-cpi-release#60 on the assumption the stemcell would
# take it over. The jammy stemcell only ever picked up the systemd-binfmt mask
# above, so we reproduce the CPI's full allow-list here.
#
# This removes the `.wants` symlinks (equivalent to `systemctl disable`): units
# are dropped from the boot sequence but can still start as dependencies of a
# kept unit. The keep patterns mirror the historical CPI list exactly. Deriving
# the set at build time keeps it correct as the stemcell's package set changes.
run_in_chroot "$chroot" "
find /etc/systemd/system /lib/systemd/system \
  -type l \
  -path '*.wants/*' \
  -not -name '*bosh-agent*' \
  -not -name '*dbus*' \
  -not -name '*journald*' \
  -not -name '*logrotate*' \
  -not -name '*runit*' \
  -not -name '*ssh*' \
  -not -name '*systemd-user-sessions*' \
  -not -name '*systemd-tmpfiles*' \
  -delete
"
