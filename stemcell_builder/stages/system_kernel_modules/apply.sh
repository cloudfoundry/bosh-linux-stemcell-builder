#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

stage_dir=$(readlink -nf $(dirname $0))

echo '# prevent modules from being loaded
install usb-storage /bin/true
install bluetooth /bin/true
install tipc /bin/true
install sctp /bin/true
install dccp /bin/true
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install rds /bin/true
install floppy /bin/true
install algif_aead /bin/true
' >> $chroot/etc/modprobe.d/blacklist.conf

echo '# prevent nouveau from loading
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off' >> $chroot/etc/modprobe.d/blacklist-nouveau.conf

rm -rf $chroot/lib/modules/*/kernel/zfs $chroot/usr/src/linux-headers-*/zfs

# Must match the kernel package installed by the system_kernel / system_fips_kernel stages
kernel_package=linux-generic
if [ "${stemcell_operating_system_variant}" == "fips" ]; then
  kernel_package=linux-fips
  if [ -n "${UBUNTU_FIPS_USE_IAAS_KERNEL:-}" ]; then
    kernel_package=linux-$stemcell_infrastructure-fips
  fi
fi

# Delete kernel modules that stemcells don't need, as listed in <kernel package>.csv
modules_csv=$stage_dir/$kernel_package.csv
if [ ! -f "$modules_csv" ]; then
  echo "ERROR: no kernel module list for $kernel_package." \
    "Create stemcell_builder/stages/system_kernel_modules/$kernel_package.csv (see linux-generic.csv)." >&2
  exit 1
fi
for modules_dir in "$chroot"/usr/lib/modules/*; do
  "$stage_dir/remove_kernel_modules.sh" "$modules_dir" "$modules_csv"
  run_in_chroot $chroot "depmod -a $(basename "$modules_dir")"
done

mount --bind /sys "$chroot/sys"
add_on_exit "umount $chroot/sys"
run_in_chroot $chroot "update-initramfs -u -k all"
