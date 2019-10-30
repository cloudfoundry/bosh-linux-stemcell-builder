#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

# This is intentional -- it is designed to be called in a pipe
extracted_image_path=$(cat)

converted_raw_path=$(mktemp -d)

MB=$((1024*1024))
size=$(qemu-img info -f raw --output json "$extracted_image_path" | \
       awk 'match($0, /"virtual-size": ([0-9]+),/, val) {print val[1]}')

rounded_size=$((($size/$MB + 1)*$MB))
qemu-img resize $extracted_image_path $rounded_size

# The size of the VHD for Azure must be a whole number in megabytes.
qemu-img convert -O vpc -o subformat=fixed,force_size $extracted_image_path $converted_raw_path/root.vhd

echo $converted_raw_path/root.vhd
