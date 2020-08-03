#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}
image_mount_point=${work}/mnt

## unmap the loop device in case it's already mapped
#umount ${image_mount_point}/proc || true
#umount ${image_mount_point}/sys || true
#umount ${image_mount_point} || true
#losetup -j ${disk_image} | cut -d ':' -f 1 | xargs --no-run-if-empty losetup -d
kpartx -dv ${disk_image}

# note: if the above kpartx command fails, it's probably because the loopback device needs to be unmapped.
# in that case, try this: sudo dmsetup remove loop0p1

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"

device_partition=$(kpartx -sav ${device} | grep "^add" | cut -d" " -f3)
add_on_exit "kpartx -dv ${device}"

loopback_dev="/dev/mapper/${device_partition}"

# Mount partition
image_mount_point=${work}/mnt
mkdir -p ${image_mount_point}

mount ${loopback_dev} ${image_mount_point}
add_on_exit "umount ${image_mount_point}"

# == Guide to variables in this script (all paths are defined relative to the real root dir, not the chroot)

# work: the base working directory outside the chroot
#      eg: /mnt/stemcells/aws/xen/centos/work/work
# disk_image: path to the stemcell disk image
#      eg: /mnt/stemcells/aws/xen/centos/work/work/aws-xen-centos.raw
# device: path to the loopback devide mapped to the entire disk image
#      eg: /dev/loop0
# loopback_dev: device node mapped to the main partition in disk_image
#      eg: /dev/mapper/loop0p1
# image_mount_point: place where loopback_dev is mounted as a filesystem
#      eg: /mnt/stemcells/aws/xen/centos/work/work/mnt

# Generate random password
random_password=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16)

mkdir -p ${image_mount_point}/tmp/grub
add_on_exit "rm -rf ${image_mount_point}/tmp/grub"

touch ${image_mount_point}/tmp/grub/${stemcell_image_name}

mount --bind $work/${stemcell_image_name} ${image_mount_point}/tmp/grub/${stemcell_image_name}
add_on_exit "umount ${image_mount_point}/tmp/grub/${stemcell_image_name}"

cat > ${image_mount_point}/tmp/grub/device.map <<EOS
(hd0) ${stemcell_image_name}
EOS

run_in_chroot ${image_mount_point} "
cd /tmp/grub
grub --device-map=device.map --batch <<EOF
root (hd0,0)
setup (hd0)
EOF
"

# Figure out uuid of partition
uuid=$(blkid -c /dev/null -sUUID -ovalue ${loopback_dev})
kernel_version=$(basename $(ls -rt ${image_mount_point}/boot/vmlinuz-* |tail -1) |cut -f2-8 -d'-')
initrd_file="initrd.img-${kernel_version}"
os_name=$(source ${image_mount_point}/etc/lsb-release ; echo -n ${DISTRIB_DESCRIPTION})

cat > ${image_mount_point}/etc/fstab <<FSTAB
# /etc/fstab Created by BOSH Stemcell Builder
UUID=${uuid} / ext4 defaults 1 1
FSTAB

cat > ${image_mount_point}/boot/grub/grub.cfg <<GRUB_CONF
default=0
timeout=1
title ${os_name} (${kernel_version})
  root (hd0,0)
  kernel /boot/vmlinuz-${kernel_version} ro root=UUID=${uuid} net.ifnames=0 biosdevname=0 selinux=0 cgroup_enable=memory swapaccount=1 console=ttyS0,115200n8 console=tty0 earlyprintk=ttyS0 rootdelay=300 ipv6.disable=1 audit=1 nvme_core.io_timeout=255 nvme_core.max_retries=10
  initrd /boot/${initrd_file}
GRUB_CONF

# For grub.cfg
if [ -f ${image_mount_point}/boot/grub/grub.cfg ];then
  sed -i "/^timeout=/a password --md5 *" ${image_mount_point}/boot/grub/grub.cfg
  chown -fLR root:root ${image_mount_point}/boot/grub/grub.cfg
  chmod 600 ${image_mount_point}/boot/grub/grub.cfg
fi

run_in_chroot ${image_mount_point} "rm -f /boot/grub/menu.lst"
run_in_chroot ${image_mount_point} "ln -s ./grub.cfg /boot/grub/menu.lst"
