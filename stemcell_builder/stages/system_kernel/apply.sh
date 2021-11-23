#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash


mkdir -p $chroot/tmp


if [[  "${DISTRIB_CODENAME}" == "bionic" ]]; then
  # remove additional drivers like crc32c kernel module.
  sed -i "/^add_drivers.*/d" $chroot/etc/dracut.conf.d/10-debian.conf
  pkg_mgr install linux-generic-hwe-18.04
elif [[  "${DISTRIB_CODENAME}" == "impish" ]]; then
  sed -i "/^add_drivers.*/d" $chroot/etc/dracut.conf.d/10-debian.conf
  pkg_mgr install linux-generic-hwe-20.04
elif [[  "${DISTRIB_CODENAME}" == "jammy" ]]; then
  sed -i "/^add_drivers.*/d" $chroot/etc/dracut.conf.d/10-debian.conf
  pkg_mgr install linux-generic-hwe-20.04
elif [[ "${DISTRIB_CODENAME}" == "xenial" ]]; then
  pkg_mgr install linux-generic-hwe-16.04
else
  pkg_mgr install wireless-crda linux-generic-lts-xenial
fi
