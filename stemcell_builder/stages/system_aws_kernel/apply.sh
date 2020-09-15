#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [[  "${DISTRIB_CODENAME}" == "bionic" ]]; then
  pkg_mgr install linux-aws-lts-18.04
elif [[ "${DISTRIB_CODENAME}" == "xenial" ]]; then
  pkg_mgr install linux-aws-hwe
fi

rm -rf /lib/modules/*/kernel/zfs
rm -rf /usr/src/linux-headers-*/zfs
