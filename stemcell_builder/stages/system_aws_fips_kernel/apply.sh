#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash
source $base_dir/lib/prelude_fips.bash

mount --bind /sys "$chroot/sys"
add_on_exit "umount $chroot/sys"

# those packages need to be installed from the FIPS repo and hold
# TODO switch to aws specific packages once available
# FIPS_PKGS="linux-image-aws-fips linux-aws-fips linux-headers-aws-fips linux-modules-extra-5.15.0-73-fips"
FIPS_PKGS="ubuntu-fips linux-modules-extra-5.15.0-73-fips"

mock_grub_probe
write_ua_client_config "aws"
ua_attach 
ua_enable_fips 
pkg_mgr install "${FIPS_PKGS}"
ua_detach
unmock_grub_probe
