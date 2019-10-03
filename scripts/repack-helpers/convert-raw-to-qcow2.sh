#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

# This is intentional -- it is designed to be called in a pipe
extracted_image_path=$(cat)

converted_raw_path=$(mktemp -d)

qemu-img convert -c -O qcow2 -o compat=0.10 $extracted_image_path $converted_raw_path/root.img

echo $converted_raw_path/root.img
