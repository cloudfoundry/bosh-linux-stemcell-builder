#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
  sed -i "/^pool /d" $chroot/etc/chrony/chrony.conf
  echo -e "\n# Steps the system time at boot if off by more than 3 seconds" >> $chroot/etc/chrony/chrony.conf
  echo -e "makestep 3 1" >> $chroot/etc/chrony/chrony.conf
  cp $chroot/etc/chrony/chrony.conf{,.base}
  cp $dir/assets/chrony-updater $chroot/$bosh_dir/bin/sync-time
else
  # setup crontab to update ntpdate with new ntp servers as provided by agent
  cp $dir/assets/ntpdate $chroot/$bosh_dir/bin/sync-time

  echo "0,15,30,45 * * * * ${bosh_app_dir}/bosh/bin/sync-time" > $chroot/tmp/ntpdate.cron

  mkdir -p $chroot/$bosh_dir/log

  run_in_bosh_chroot $chroot "
  crontab -u root /tmp/ntpdate.cron
  "

  rm $chroot/tmp/ntpdate.cron
fi

chmod 0755 $chroot/$bosh_dir/bin/sync-time
