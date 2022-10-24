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

# TODO: seems useless as /var/log is mounted later on
for filename in ${filenames[@]}
do
  fullpath=/var/log/$filename
  run_in_bosh_chroot $chroot "
    touch ${fullpath} && chown syslog:syslog ${fullpath} && chmod 600 ${fullpath}
  "
done

# wait for var/log to be mounted
mkdir -p $chroot/usr/local/bin
cp -f $assets_dir/wait_for_var_log_to_be_mounted $chroot/usr/local/bin/wait_for_var_log_to_be_mounted
chmod 755 $chroot/usr/local/bin/wait_for_var_log_to_be_mounted
mkdir -p $chroot/etc/systemd/system/rsyslog.service.d/
cp -f $assets_dir/override.conf $chroot/etc/systemd/system/rsyslog.service.d/00-override.conf

# set storage to volatile as /var/log is mounted later on and causes journald to stop as it no longer can write to /var/log/journal
mkdir $chroot/etc/systemd/journald.conf.d/
cp -f $assets_dir/journal-override.conf $chroot/etc/systemd/journald.conf.d/00-override.conf
