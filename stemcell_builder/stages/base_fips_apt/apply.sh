#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash
source $base_dir/lib/prelude_fips.bash
source $base_dir/lib/prelude_bosh.bash

mount --bind /sys "$chroot/sys"
add_on_exit "umount $chroot/sys"

FIPS_PKGS="openssh-client openssh-server openssl openssl-fips-module-3 libssl3 libssl-dev fips-initramfs libgcrypt20 libgcrypt20-hmac libgcrypt20-dev fips-initramfs"

mock_grub_probe
ua_attach
ua_enable_fips
write_fips_cmdline_conf
pkg_mgr install --allow-downgrades "${FIPS_PKGS}"
ua_detach
unmock_grub_probe

restrict_binary_setuid

# FIPS only allows specific MACs. See "Security Policy" from
# https://csrc.nist.gov/projects/cryptographic-module-validation-program/Certificate/3632
sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
echo 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256' >> $chroot/etc/ssh/sshd_config
