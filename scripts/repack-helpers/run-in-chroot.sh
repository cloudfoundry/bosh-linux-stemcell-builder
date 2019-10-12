#!/bin/bash -eux

if [ -t 0 ];then
  echo "USAGE: $0 [command to run] <<< chroot"
fi

chroot=$(cat)

mount -o bind /etc/resolv.conf $chroot/etc/resolv.conf
cleanup() {
  umount $chroot/etc/resolv.conf
}

trap cleanup EXIT

chroot $chroot env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@" &> /dev/stderr

echo $chroot
