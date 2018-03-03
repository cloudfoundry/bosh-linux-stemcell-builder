#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
  cp -f $assets_dir/remount-rootdir-as-rprivate.service $chroot/etc/systemd/system/remount-rootdir-as-rprivate.service
  run_in_bosh_chroot $chroot "systemctl enable remount-rootdir-as-rprivate.service"
fi
