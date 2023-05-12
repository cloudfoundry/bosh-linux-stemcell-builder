#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Explicit make the mount point for bind-mount
# Otherwise using none ubuntu host will fail creating vm
mkdir -p $chroot/warden-cpi-dev

# Run system services via runit and replace /usr/sbin/service with a script which call runit
mkdir -p $chroot/etc/sv/
# TODO: figure out why this is a existing symlink now in jammy by default
if [[ "${DISTRIB_CODENAME}" != 'jammy' ]]; then
  mkdir -p $chroot/etc/service/
fi
cp -a $assets_dir/runit/{ssh,rsyslog,cron} $chroot/etc/sv/

run_in_chroot $chroot "
chmod +x /etc/sv/{ssh,rsyslog,cron}/run
ln -s /etc/sv/{ssh,rsyslog,cron} /etc/service/
"

# Remove systemd setting from rsyslog as warden doesn't use systemd
sed -i "/^\$SystemLogSocketName /d" /etc/rsyslog.conf

# Pending for disk_quota
#run_in_chroot $chroot "
#ln -s /proc/self/mounts /etc/mtab
#"

# this version of unshare has the -p flag (trusty has an old version)
# this is used to launch upstart as PID 1, in tests
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
      "SkipDiskSetup": true
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
