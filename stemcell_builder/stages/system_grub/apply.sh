#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Install the GRUB EFI packages matching the target architecture. Defaults to
# amd64 so existing builds are unchanged; arm64 uses the arm64 EFI packages.
if [ "$(stemcell_target_arch)" == "arm64" ]; then
  # ARM64 has no "grub2" metapackage; grub-efi-arm64 is the equivalent.
  pkg_mgr install grub-efi-arm64 grub-efi-arm64-bin grub-efi-arm64-signed shim-signed
else
  pkg_mgr install grub2 grub-efi-amd64-bin grub-efi-amd64-signed shim-signed
fi

# When a kernel is installed, update-grub is run per /etc/kernel-img.conf.
# It complains when /boot/grub/menu.lst doesn't exist, so create it.
mkdir -p $chroot/boot/grub
touch $chroot/boot/grub/menu.lst
