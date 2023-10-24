#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash
source $base_dir/etc/settings.bash


mkdir -p $chroot/tmp


if [[  "${DISTRIB_CODENAME}" == "bionic" ]]; then
  pkg_mgr install linux-generic-hwe-18.04
elif [[  "${DISTRIB_CODENAME}" == "jammy" ]]; then
  pkg_mgr install initramfs-tools linux-generic-hwe-22.04
elif [[ "${DISTRIB_CODENAME}" == "xenial" ]]; then
  pkg_mgr install linux-generic-hwe-16.04
else
  pkg_mgr install wireless-crda linux-generic-lts-xenial
fi
