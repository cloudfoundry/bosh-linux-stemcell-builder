#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

touch "$chroot/etc/environment"
sed -i '/^PATH/d' "$chroot/etc/environment"
echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/var/vcap/bosh/bin"' >> "$chroot/etc/environment"
