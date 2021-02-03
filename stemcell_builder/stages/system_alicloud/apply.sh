#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [[ "${DISTRIB_CODENAME}" != 'xenial' ]]; then
  echo "acpiphp" >> $chroot/etc/modules
fi

# Alicloud does not support ext4 feature 'metadata_csum'.
# Remove it from root image and also disable it inside image for all ext4 filesystems created afterwards.
sed -i "s/metadata_1csum,//g" /etc/mke2fs.conf
sed -i "s/metadata_csum,//g" $chroot/etc/mke2fs.conf
