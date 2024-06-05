#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-image-directory'
  exit 2
fi

image_path=$(cat)
chroot=$(mktemp -d)

## NOTE: Certain stemcells now have EFI support. To do this, they have an initial, FAT32 partition at the head of the disk and
##       the normal stemcell data partition at the tail. So, we're now assuming that if there are multiple partitions in a
##       disk image, that only the last one in the list is relevant.
device=$(kpartx -sav ${image_path%%/disk.raw}/disk.raw | grep '^add' | tail -n1 | cut -d' ' -f3)
mount -o loop,rw "/dev/mapper/${device}" ${chroot}
echo $chroot
