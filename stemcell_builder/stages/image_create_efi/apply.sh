#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install sfdisk if not available - it works better than parted on Docker Desktop for Apple Silicon
if ! which sfdisk > /dev/null 2>&1; then
  echo "Installing fdisk package (provides sfdisk)..."
  apt-get update -qq && apt-get install -y -qq fdisk
fi

disk_image=${work}/${stemcell_image_name}

# image_create_disk_size is in MiB
dd if=/dev/null of=${disk_image} bs=1M seek=${image_create_disk_size} 2> /dev/null

# Partition the disk image using sfdisk
# sfdisk works better than parted in virtualized environments (Docker Desktop on Apple Silicon)
# Partition layout:
#   - Partition 1: EFI System Partition (ESP), ~49MiB, type EF (EFI)
#   - Partition 2: Linux root partition, remaining space, type 83 (Linux)
sfdisk ${disk_image} <<EOF
label: dos
unit: sectors

# First partition: EFI (starts at 2048 sectors = 1MiB, size ~48MiB = 98304 sectors)
start=2048, size=98304, type=ef, bootable
# Second partition: Linux root (starts after EFI partition, uses remaining space)
start=100352, type=83
EOF

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
time rsync -aHA $chroot/ ${image_mount_point}