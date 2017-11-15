#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
  asset="chrony-updater"

  sed -i "/^pool /d" $chroot/etc/chrony/chrony.conf
  cp $chroot/etc/chrony/chrony.conf{,.base}
else
  asset="ntpdate"
fi

# setup crontab to update chronyd/ntpdate with new ntp servers as provided by agent
cp $dir/assets/$asset $chroot/$bosh_dir/bin/ntpdate

chmod 0755 $chroot/$bosh_dir/bin/ntpdate
echo "0,15,30,45 * * * * ${bosh_app_dir}/bosh/bin/ntpdate" > $chroot/tmp/ntpdate.cron

mkdir -p $chroot/$bosh_dir/log

run_in_bosh_chroot $chroot "
crontab -u root /tmp/ntpdate.cron
"

rm $chroot/tmp/ntpdate.cron
