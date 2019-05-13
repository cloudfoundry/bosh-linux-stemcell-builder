#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ ${OS_TYPE} == 'ubuntu' ]; then
  cp $dir/assets/chrony-updater-azure $chroot/$bosh_dir/bin/sync-time
  chmod 0755 $chroot/$bosh_dir/bin/sync-time
fi

