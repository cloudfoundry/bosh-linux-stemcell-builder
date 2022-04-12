#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash


mkdir -p $chroot/tmp

run_in_chroot $chroot "echo deb https://${PPA_USERNAME}:${PPA_PASSWORD}@${PPA_SOURCE} > /etc/apt/sources.list.d/patch_kernel.list"
run_in_chroot $chroot "echo deb-src https://${PPA_USERNAME}:${PPA_PASSWORD}@${PPA_SOURCE} >> /etc/apt/sources.list.d/patch_kernel.list"
run_in_chroot $chroot "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ${PPA_KEY}"

pkg_mgr install ${KERNEL_PACKAGES}

run_in_chroot $chroot "rm /etc/apt/sources.list.d/patch_kernel.list"
