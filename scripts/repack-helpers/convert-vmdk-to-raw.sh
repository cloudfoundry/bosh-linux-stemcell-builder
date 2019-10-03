#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

# This is intentional -- it is designed to be called in a pipe
extracted_image_path=$(cat)

converted_raw_path=$(mktemp -d)

qemu-img convert $extracted_image_path/image-disk1.vmdk $converted_raw_path/disk.raw

echo $converted_raw_path/disk.raw
