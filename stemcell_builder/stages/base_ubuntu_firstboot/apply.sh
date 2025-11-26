#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

install -D -m 0644 \
  $assets_dir/etc/systemd/system/firstboot.service \
  $chroot/etc/systemd/system/firstboot.service

run_in_chroot $chroot "systemctl enable firstboot.service"
