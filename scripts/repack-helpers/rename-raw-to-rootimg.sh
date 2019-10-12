#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

# This is intentional -- it is designed to be called in a pipe
disk_raw_path=$(cat)

root_img_path=$(mktemp -d)

ln $disk_raw_path $root_img_path/root.img

echo $root_img_path/root.img
