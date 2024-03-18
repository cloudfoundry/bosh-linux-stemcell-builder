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
  ## As was discussed in Bosh Ecosystem Team Retro on 2024-02-14, team policy is now
  ## to publish stemcells that use non-HWE kernels so that we ship stemcells that
  ## use LTS kernels. We've decided to switch to LTS kernels in the hopes that we will
  ## see a lower defect rate than with the HWE kernels, which seem to roughly track
  ## the latest kernel version. For Jammy and subsequent stemcell lines (that is Noble
  ## and later), don't switch to the HWE kernels unless you have a good reason and
  ## have discussed it with the rest of the team, or whoever is currently responsible
  ## for the Linux Stemcell.
  pkg_mgr install initramfs-tools linux-generic
elif [[ "${DISTRIB_CODENAME}" == "xenial" ]]; then
  pkg_mgr install linux-generic-hwe-16.04
else
  pkg_mgr install wireless-crda linux-generic-lts-xenial
fi
