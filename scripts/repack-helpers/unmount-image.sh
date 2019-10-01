#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< mounted-image-directory'
  echo 'example: echo /tmp/chroot | unmount-image.sh'
  exit 2
fi

mounted_image_directory=$(cat)
mounted_loopback=$(mount | grep $mounted_image_directory | cut -f1 -d' ' | sed 's/p[[:digit:]]*$//')

# extract loopN from /path/to/device/loopN
device=$(basename $mounted_loopback)
raw_disk=$(losetup -l | awk "\$1 == \"/dev/${device}\" { print \$6 }")
umount $mounted_image_directory
kpartx -d $raw_disk >/dev/null
echo $raw_disk
