#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

extracted_image_path=$(cat)

converted_raw_path=$(mktemp -d)

qemu-img convert $extracted_image/image-disk1.vmdk $converted_raw_path/disk.raw

echo $converted_raw_path
