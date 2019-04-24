#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

sed -i '/PATH/s/"$/:\/var\/vcap\/bosh\/bin/' "$chroot/etc/environment"
