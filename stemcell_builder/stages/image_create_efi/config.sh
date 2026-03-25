#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# sfdisk will be installed at runtime if not available (see apply.sh)
# kpartx is required for partition mapping
assert_available kpartx

if [ -z "${image_create_disk_size:-}" ]
then
  image_create_disk_size=1225
fi

persist_value image_create_disk_size
persist_value stemcell_image_name
