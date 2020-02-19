#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
  preferred=grub
  fallback=grub2
else
  preferred=grub2
  fallback=grub
fi

if pkg_exists $preferred; then
  pkg_mgr install $preferred
elif pkg_exists $fallback; then
  pkg_mgr install $fallback
else
  echo "Can't find grub or grub2 package to install"
  exit 2
fi

if [ -d $chroot/usr/lib/grub/x86* ] # classic GRUB on Ubuntu
then

  rsync -a $chroot/usr/lib/grub/x86*/ $chroot/boot/grub/

elif [ -d $chroot/usr/lib/grub/i386* ] # grub-pc on bionic
then

  rsync -a $chroot/usr/lib/grub/i386*/ $chroot/boot/grub/

else

  echo "Can't find GRUB or GRUB 2 files, exiting"
  exit 2

fi

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
mkdir -p $chroot/boot/grub
touch $chroot/boot/grub/menu.lst
