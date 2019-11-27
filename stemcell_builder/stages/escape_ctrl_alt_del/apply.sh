#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

echo 'Overriding for Control-Alt-Delete'
mkdir -p $chroot/etc/init
echo 'exec /usr/bin/logger -p security.info "Control-Alt-Delete pressed"' > $chroot/etc/init/control-alt-delete.override
