#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

# This is intentional -- it is designed to be called in a pipe
root_img_path=$(cat)

disk_raw_path=$(mktemp -d)

ln $root_img_path/root.img $disk_raw_path/disk.raw

echo $disk_raw_path/disk.raw
