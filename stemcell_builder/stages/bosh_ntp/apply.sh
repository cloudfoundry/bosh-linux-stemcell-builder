#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

sed -i "/^pool /d" $chroot/etc/chrony/chrony.conf
echo -e "\n# Steps the system time at boot if off by more than 3 seconds" >> $chroot/etc/chrony/chrony.conf
echo -e "makestep 3 1" >> $chroot/etc/chrony/chrony.conf
cp $chroot/etc/chrony/chrony.conf{,.base}
cp $dir/assets/chrony-updater $chroot/$bosh_dir/bin/sync-time

chmod 0755 $chroot/$bosh_dir/bin/sync-time
