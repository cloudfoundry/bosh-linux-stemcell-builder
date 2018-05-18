#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash


mkdir -p $chroot/tmp


if [[ "${DISTRIB_CODENAME}" == "xenial" ]]; then
  pkg_mgr install linux-generic-hwe-16.04-edge
else
  pkg_mgr install wireless-crda linux-generic-lts-xenial
fi
