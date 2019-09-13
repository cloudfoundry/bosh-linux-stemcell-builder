#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Add configuration files
cp $assets_dir/rsyslog.conf $chroot/etc/rsyslog.conf

# configure upstart to start rsyslog if its config dir exists
if [ -d $chroot/etc/init ]; then
  cp $assets_dir/rsyslog_upstart.conf $chroot/etc/init/rsyslog.conf
fi

cp $assets_dir/rsyslog_logrotate.conf $chroot/etc/logrotate.d/rsyslog

# erase default rsyslog.d contents in case it was populated by an OS package;
# create the dir in case we're using the custom-built local installation
if [ -d $chroot/etc/rsyslog.d ]; then
  rm -rf $chroot/etc/rsyslog.d/*
else
  mkdir -p $chroot/etc/rsyslog.d
fi

cp $assets_dir/enable-kernel-logging.conf $chroot/etc/rsyslog.d/enable-kernel-logging.conf
cp $assets_dir/avoid-startup-deadlock.conf $chroot/etc/rsyslog.d/avoid-startup-deadlock.conf

cp -f $assets_dir/rsyslog_50-default.conf $chroot/etc/rsyslog.d/50-default.conf

# Add user/group
# add syslog to the vcap group in a separate step in case the syslog user already exists
run_in_bosh_chroot $chroot "
  useradd --system --user-group --no-create-home --shell /sbin/nologin syslog || true
  usermod -G vcap syslog
"

# Configure /var/log directory
filenames=( auth.log cloud-init.log daemon.log debug kern.log lpr.log mail.err mail.info \
              mail.log mail.warn messages news/news.crit news/news.err \
              news/news.notice syslog user.log cron.log )


run_in_bosh_chroot $chroot "
  mkdir -p /var/log/news
"

for filename in ${filenames[@]}
do
  fullpath=/var/log/$filename
  run_in_bosh_chroot $chroot "
    touch ${fullpath} && chown syslog:syslog ${fullpath} && chmod 600 ${fullpath}
  "
done

# init.d configuration is different for each OS
if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  mkdir -p $chroot/etc/systemd/system/var-log.mount.d/
  cp -f $assets_dir/start_rsyslog_on_mount.conf $chroot/etc/systemd/system/var-log.mount.d/start_rsyslog_on_mount.conf
  mkdir -p $chroot/etc/systemd/system/syslog.socket.d/
  cp -f $assets_dir/rsyslog_to_syslog_service.conf $chroot/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf
  run_in_bosh_chroot $chroot "systemctl disable rsyslog.service"

  if is_ppc64le; then
    sed -i "s@/dev/xconsole@/dev/console@g" $chroot/etc/rsyslog.d/50-default.conf
  fi
elif [ -f $chroot/etc/redhat-release ] # Centos or RHEL
then
  sed -i "s@-/var/log/syslog@-/var/log/messages@g" $chroot/etc/rsyslog.d/50-default.conf
  mkdir -p $chroot/etc/systemd/system/var-log.mount.d/
  cp -f $assets_dir/start_rsyslog_on_mount.conf $chroot/etc/systemd/system/var-log.mount.d/start_rsyslog_on_mount.conf
  mkdir -p $chroot/etc/systemd/system/syslog.socket.d/
  cp -f $assets_dir/rsyslog_to_syslog_service.conf $chroot/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf
  run_in_bosh_chroot $chroot "systemctl disable rsyslog.service"
elif [ -f $chroot/etc/SuSE-release ] # openSUSE
then
  sed -i "s@/dev/xconsole@/dev/console@g" $chroot/etc/rsyslog.d/50-default.conf
  mkdir -p $chroot/etc/systemd/system/var-log.mount.d/
  cp -f $assets_dir/start_rsyslog_on_mount.conf $chroot/etc/systemd/system/var-log.mount.d/start_rsyslog_on_mount.conf
  mkdir -p $chroot/etc/systemd/system/syslog.socket.d/
  cp -f $assets_dir/rsyslog_to_syslog_service.conf $chroot/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf
  run_in_bosh_chroot $chroot "systemctl disable rsyslog.service"
elif [ -f $chroot/etc/photon-release ] # PhotonOS
then
  sed -i "s@/dev/xconsole@/dev/console@g" $chroot/etc/rsyslog.d/50-default.conf
else
  echo "Unknown OS, exiting"
  exit 2
fi
