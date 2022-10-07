#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Add configuration files
cp $assets_dir/rsyslog.conf $chroot/etc/rsyslog.conf

cp $assets_dir/rsyslog_logrotate.conf $chroot/etc/logrotate.d/rsyslog

# erase default rsyslog.d contents in case it was populated by an OS package;
# create the dir in case we're using the custom-built local installation
if [ -d $chroot/etc/rsyslog.d ]; then
  rm -rf $chroot/etc/rsyslog.d/*
else
  mkdir -p $chroot/etc/rsyslog.d
fi

cp -f $assets_dir/rsyslog_50-default.conf $chroot/etc/rsyslog.d/50-default.conf

# Add user/group
# add syslog to the vcap group in a separate step in case the syslog user already exists
run_in_bosh_chroot $chroot "
  useradd --system --user-group --no-create-home --shell /sbin/nologin syslog || true
  usermod -G vcap syslog
"

# Configure /var/log directory
filenames=( auth.log cloud-init.log daemon.log kern.log syslog cron.log )

for filename in ${filenames[@]}
do
  fullpath=/var/log/$filename
  run_in_bosh_chroot $chroot "
    touch ${fullpath} && chown syslog:syslog ${fullpath} && chmod 600 ${fullpath}
  "
done

# init.d configuration is different for each OS
mkdir -p $chroot/usr/local/bin
grep -q "ExecStart=" $chroot/lib/systemd/system/rsyslog.service || (echo "Unable to find ExecStart key in $chroot/lib/systemd/system/rsyslog.service"; exit 1)
sed '/^Requires=.*/a After=var-log.mount' $chroot/lib/systemd/system/rsyslog.service > $chroot/etc/systemd/system/rsyslog.service

mkdir -p $chroot/etc/systemd/system/syslog.socket.d/
cp -f $assets_dir/rsyslog_to_syslog_service.conf $chroot/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf
