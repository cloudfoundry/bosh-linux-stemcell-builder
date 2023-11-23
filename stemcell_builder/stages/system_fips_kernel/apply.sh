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
pkg_mgr install fips-initramfs linux-fips
ua_detach
unmock_grub_probe
