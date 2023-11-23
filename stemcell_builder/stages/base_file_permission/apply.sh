#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

chmod 0000 $chroot/etc/gshadow
chown root:root $chroot/etc/gshadow

chmod 0000 $chroot/etc/shadow
chown root:root $chroot/etc/shadow

restrict_binary_setuid
