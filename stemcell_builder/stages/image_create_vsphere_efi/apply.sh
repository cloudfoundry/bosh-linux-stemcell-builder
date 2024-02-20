#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}

# image_create_disk_size is in MiB
dd if=/dev/null of=${disk_image} bs=1M seek=${image_create_disk_size} 2> /dev/null
parted --script ${disk_image} mklabel gpt
parted --script ${disk_image} mkpart ESP fat32 1MiB 32MiB
parted --script ${disk_image} mkpart primary ext2 33MiB 100%

# unmap the loop device in case it's already mapped
timeout 100 bash -c "
until kpartx -dv ${disk_image}; do
  echo 'Waiting for loop device to be free'
  echo 'Running lsof'
  lsof ${disk_image}
  sleep 1
done
"

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"

device_partition_efi=$(kpartx -sav ${device} | cut -d" " -f3 | head -1)
device_partition_root=$(kpartx -sav ${device} | cut -d" " -f3 | tail -1)
add_on_exit "kpartx -dv ${device}"

loopback_efi_dev="/dev/mapper/${device_partition_efi}"
loopback_root_dev="/dev/mapper/${device_partition_root}"

# Format the partitions
mkfs.vfat ${loopback_efi_dev}
mkfs.ext4 ${loopback_root_dev}

# Mount partition
image_mount_point=${work}/mnt

mkdir -p ${image_mount_point}
mount ${loopback_root_dev} ${image_mount_point}
add_on_exit "umount ${image_mount_point}"

mkdir -p ${image_mount_point}/boot/efi
mount ${loopback_efi_dev} ${image_mount_point}/boot/efi
add_on_exit "umount ${image_mount_point}/boot/efi"

# Copy root, don't cross mount-points, skipping /boot/efi is okay; it's empty
time rsync -axHA $chroot/ ${image_mount_point}
