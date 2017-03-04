#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cp -p $assets_dir/static_libraries_list.txt $chroot/var/vcap/bosh/etc/static_libraries_list
