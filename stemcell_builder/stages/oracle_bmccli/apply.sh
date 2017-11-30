#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cd ${dir}/bosh-bmccli
mv bosh-bmccli $chroot/var/vcap/bosh/bin/bosh-blobstore-bmc
chmod +x $chroot/var/vcap/bosh/bin/bosh-blobstore-bmc
