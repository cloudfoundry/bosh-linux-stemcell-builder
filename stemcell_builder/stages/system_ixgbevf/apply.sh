#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir $chroot/usr/src/ixgbevf-4.3.4

tar -xzf $assets_dir/ixgbevf-4.3.4.tar.gz \
  -C $chroot/usr/src/ixgbevf-4.3.4 \
  --strip-components=1

cp $assets_dir/usr/src/ixgbevf-4.3.4/dkms.conf $chroot/usr/src/ixgbevf-4.3.4/dkms.conf

pkg_mgr install dkms

kernelver=$( ls -rt $chroot/lib/modules | tail -1 )
run_in_chroot $chroot "dkms -k ${kernelver} add -m ixgbevf -v 4.3.4"
run_in_chroot $chroot "dkms -k ${kernelver} build -m ixgbevf -v 4.3.4"
run_in_chroot $chroot "dkms -k ${kernelver} install -m ixgbevf -v 4.3.4"


if [ -f ${chroot}/etc/debian_version ] # Ubuntu
then
  run_in_chroot $chroot "update-initramfs -c -k all"
elif [ -f ${chroot}/etc/redhat-release ] # Centos or RHEL
then
  run_in_chroot $chroot "dracut --force --kver ${kernelver}"
elif [ -f ${chroot}/etc/photon-release ] # PhotonOS
then
  run_in_chroot $chroot "dracut --force --kver ${kernelver}"
elif [ -f ${chroot}/etc/SuSE-release ] # openSUSE
then
  run_in_chroot $chroot "dracut --force --kver ${kernelver}"
else
  echo "Unknown OS, exiting"
  exit 2
fi
