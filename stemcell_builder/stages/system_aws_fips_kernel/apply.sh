#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash
source $base_dir/lib/prelude_fips.bash
source $base_dir/lib/prelude_bosh.bash

mount --bind /sys "$chroot/sys"
add_on_exit "umount $chroot/sys"

mock_grub_probe
ua_attach
ua_enable_fips
pkg_mgr install linux-fips
ua_detach
unmock_grub_probe

# TODO: this should be handled in the base_file_permissions stage. but because we are installing a kernel again it needs to run again.
#        we should check if we need to move the stage from the os_image builder
# remove setuid binaries - except su/sudo (sudoedit is hardlinked)
run_in_bosh_chroot $chroot "
find / -xdev -perm /ug=s -type f \
  -not \( -name sudo -o -name su -o -name sudoedit \) \
  -exec chmod ug-s {} \;
"