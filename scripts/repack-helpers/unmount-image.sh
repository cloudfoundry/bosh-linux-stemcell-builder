#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< mounted-image-directory'
  exit 2
fi

mounted_image_directory=$(cat)
mounted_loopback=$(mount | grep $mounted_image_directory | cut -f1 -d' ' | sed 's/p[[:digit:]]*$//')
raw_disk=$(losetup -l | awk "\$1 == \"$mounted_loopback\" { print \$6 }")
umount $mounted_image_directory
losetup -d $mounted_loopback
echo $raw_disk
