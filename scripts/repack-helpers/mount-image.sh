#!/bin/bash -eu

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

image_path=$(cat)
chroot=$(mktemp -d)

sudo losetup --show --find ${image_path}/disk.raw
loopback=$(losetup -a | grep ${image_path}/disk.raw | cut -d ':' -f1)
sudo mount -o loop,rw ${loopback}p1 ${chroot}
echo $chroot
