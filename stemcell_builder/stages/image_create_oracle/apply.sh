#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
this_dir=$(dirname $0)

source ${base_dir}/lib/prelude_apply.bash

# Variables
disk_label=cloudimg-rootfs
disk_image=${work}/${stemcell_image_name}
image_mount_point=${work}/mnt
uefi_mount_point=${image_mount_point}/uefi

# Create the empty image
truncate --size ${image_create_disk_size}M ${disk_image}

# Partition the disk with efi and grub partitions
sgdisk --clear \
--new 14::+1M --typecode=14:ef02 --change-name=14:'BIOS boot partition' \
--new 15::+100M --typecode=15:ef00 --change-name=15:'EFI System' \
--new 1::-0 --typecode=1:8300 --change-name=1:'Linux root filesystem' \
${disk_image}

# Set partition boot flags
parted ${disk_image} set 14 bios_grub on
parted ${disk_image} set 15 boot on

# Map loop devices
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"
kpartx -avs ${device}
add_on_exit "kpartx -dv ${device}"

mapper_device=`echo $device | sed "s/dev/dev\/mapper/"`

# Setup EFI partition
mkfs.vfat -F32 ${mapper_device}p15
mkfs.ext4 -F -L "${disk_label}" ${mapper_device}p1
fatlabel ${mapper_device}p15 EFI

# Set partition uuid
uuid=`blkid -o value ${mapper_device}p1 | head -2 | tail -1`
sgdisk --partition-guid=1:${uuid} ${disk_image}

# Copy main files into the fs
mkdir -p ${image_mount_point}
mount ${mapper_device}p1 ${image_mount_point}
add_on_exit "umount ${image_mount_point}"
time rsync -aHA ${chroot}/ ${image_mount_point}

# Generate a random grub password
random_password=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16)
pbkdf2_password=`run_in_chroot ${image_mount_point} "echo -e '${random_password}\n${random_password}' | grub-mkpasswd-pbkdf2 | grep -Eo 'grub.pbkdf2.sha512.*'"`
echo "\

cat << EOF
set superusers=vcap
password_pbkdf2 vcap $pbkdf2_password
EOF" >> ${image_mount_point}/etc/grub.d/00_header

# Mount proc
mount -t proc none ${image_mount_point}/proc
add_on_exit "umount ${image_mount_point}/proc"

# GRUB 2 needs to operate on the loopback block device for the whole FS image, so we map it into the chroot environment
loopback_dev="${mapper_device}p1"
touch ${image_mount_point}${device}
mount --bind ${device} ${image_mount_point}${device}
add_on_exit "umount ${image_mount_point}${device}"

mkdir -p `dirname ${image_mount_point}${loopback_dev}`
touch ${image_mount_point}${loopback_dev}
mount --bind ${loopback_dev} ${image_mount_point}${loopback_dev}
add_on_exit "umount ${image_mount_point}${loopback_dev}"

# Configure /proc and /sys
mount -t sysfs none ${image_mount_point}/sys
add_on_exit "umount ${image_mount_point}/sys"
run_in_chroot ${image_mount_point} "update-initramfs -u"
run_in_chroot ${image_mount_point} "grub-install --skip-fs-probe --no-floppy --target=i386-pc --modules='ext2 part_gpt' ${device}"
sed -i 's/CLASS=\\\"--class gnu-linux --class gnu --class os\\\"/CLASS=\\\"--class gnu-linux --class gnu --class os --unrestricted\\\"/' ${image_mount_point}/etc/grub.d/10_linux


cat >${image_mount_point}/etc/default/grub <<EOF
GRUB_TIMEOUT=1
# For dual UEFI/GPT compatability
GRUB_PRELOAD_MODULES="part_gpt fat ext2 normal chain boot configfile linux multiboot search_fs_uuid search_label terminal serial video video_fb video_bochs usb usb_keyboard efi_gop efi_uga"
# Assorted common kernel flags
GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 selinux=0 cgroup_enable=memory swapaccount=1 console=ttyS0,115200n8 console=tty0 earlyprintk=ttyS0 rootdelay=300 ipv6.disable=1 audit=1"
GRUB_GFXPAYLOAD_LINUX=text
EOF
run_in_chroot ${image_mount_point} "GRUB_DISABLE_RECOVERY=true update-grub"

sed -i "s_/dev/loop[0-9]p1_UUID=${uuid}_g" ${image_mount_point}/boot/grub/grub.cfg
sed -i "s_/dev/mapper/loop[0-9]p1_UUID=${uuid}_g" ${image_mount_point}/boot/grub/grub.cfg
chown -fLR root:root ${image_mount_point}/boot/grub/grub.cfg
chmod 600 ${image_mount_point}/boot/grub/grub.cfg

# Install uefi
mkdir -p ${uefi_mount_point}
mount ${mapper_device}p15 ${uefi_mount_point}
add_on_exit "umount ${uefi_mount_point}"
mkdir -p ${uefi_mount_point}/EFI/BOOT
run_in_chroot ${image_mount_point} "grub-mkimage \
    -d /usr/lib/grub/x86_64-efi \
    -o /uefi/EFI/BOOT/BOOTX64.EFI \
    -p /efi/boot \
    -O x86_64-efi \
      fat iso9660 part_gpt part_msdos normal boot linux configfile loopback chain efifwsetup efi_gop \
      efi_uga ls search search_label search_fs_uuid search_fs_file gfxterm gfxterm_background \
      gfxterm_menu test all_video loadenv exfat ext2 ntfs btrfs hfsplus udf \
      multiboot serial video_bochs usb usb_keyboard all_video"

# Create boot grub.cfg
cat <<GRUBCFG | tee ${uefi_mount_point}/EFI/BOOT/grub.cfg
search --fs-uuid $uuid --set prefix
configfile (\$prefix)/boot/grub/grub.cfg
GRUBCFG
