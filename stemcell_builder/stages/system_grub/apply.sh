#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install grub or grub2
if [ $(get_os_type) == "opensuse" ] ; then
  preferred=grub2
  fallback=grub
else
  preferred=grub
  fallback=grub2
fi

if is_ppc64le; then
  # ppc64le uses grub2
  pkg_mgr install grub2
elif pkg_exists $preferred; then
  pkg_mgr install $preferred
elif pkg_exists $fallback; then
  pkg_mgr install $fallback
else
  echo "Can't find grub or grub2 package to install"
  exit 2
fi

if [ -d $chroot/usr/lib/grub/powerpc* ] # GRUB on ppc64le
then

  rsync -a $chroot/usr/lib/grub/powerpc*/ $chroot/boot/grub/

elif [ -d $chroot/usr/lib/grub/x86* ] # classic GRUB on Ubuntu
then

  rsync -a $chroot/usr/lib/grub/x86*/ $chroot/boot/grub/

elif [ -d $chroot/etc/grub.d ] # GRUB 2 on CentOS 7 or Ubuntu
then

  echo "Found grub2; grub-legacy bootloader stages not needed"

else

  echo "Can't find GRUB or GRUB 2 files, exiting"
  exit 2

fi

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
mkdir -p $chroot/boot/grub
touch $chroot/boot/grub/menu.lst
