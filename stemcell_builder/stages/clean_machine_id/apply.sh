#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# machine-id should be unique for each created vm.
echo "" > $chroot/etc/machine-id
rm -f $chroot/var/lib/dbus/machine-id
