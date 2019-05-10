#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [[ $OS_TYPE == 'ubuntu' ]]; then
  cp -p "${assets_dir}/${DISTRIB_CODENAME}_static_libraries_list.txt" $chroot/var/vcap/bosh/etc/static_libraries_list
else
  cp -p $assets_dir/static_libraries_list.txt $chroot/var/vcap/bosh/etc/static_libraries_list
fi
