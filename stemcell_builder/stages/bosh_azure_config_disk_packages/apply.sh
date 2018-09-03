#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

packages="qemu-utils"
pkg_mgr install $packages

# we need to change the permission is because stemcell requires All Stemcells Library files must have mode 0755 or less permissiv
run_in_chroot $chroot "
  chmod 0700 /usr/lib/x86_64-linux-gnu/nss/*.chk
"
