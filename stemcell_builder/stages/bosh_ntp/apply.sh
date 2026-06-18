#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

sed -i "/^pool /d" $chroot/etc/chrony/chrony.conf
cp $dir/assets/chrony-updater $chroot/$bosh_dir/bin/sync-time

chmod 0755 $chroot/$bosh_dir/bin/sync-time

mkdir -p "${chroot}/etc/systemd/system/chronyd.service.d"
cp $dir/assets/prevent_mount_locking.conf "${chroot}/etc/systemd/system/chronyd.service.d"
