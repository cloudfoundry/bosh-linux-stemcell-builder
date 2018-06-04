#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [[ "${DISTRIB_CODENAME}" != 'xenial' ]]; then
  echo "acpiphp" >> $chroot/etc/modules
fi

echo "virtio_scsi" >> $chroot/etc/modules
