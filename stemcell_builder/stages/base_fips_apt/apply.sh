#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash
source $base_dir/lib/prelude_fips.bash

# those packages need to be installed from the FIPS repo and hold
FIPS_PKGS="openssh-client openssh-server openssl libssl1.1 libssl1.1-hmac libssl-dev fips-initramfs libgcrypt20 libgcrypt20-hmac libgcrypt20-dev fips-initramfs"

mock_grub_probe
ua_attach
ua_enable_fips
write_fips_cmdline_conf
install_and_hold_packages "${FIPS_PKGS}"
ua_detach
unmock_grub_probe

# FIPS only allows specific MACs. See "Security Policy" from
# https://csrc.nist.gov/projects/cryptographic-module-validation-program/Certificate/3632
sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
echo 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256' >> $chroot/etc/ssh/sshd_config

# FIPS kernel depends on crda so do not try to remove it
# if [ -z ${UBUNTU_ADVANTAGE_TOKEN+x} ]; then
#     pkgs_to_purge="crda iw mg wireless-crda wireless-regdb"
#     pkg_mgr purge --auto-remove "$pkgs_to_purge"
# fi

# cd /opt/bosh/bosh-stemcell; STEMCELL_IMAGE=/mnt/stemcells/aws/xen/ubuntu/work/work/aws-xen-ubuntu.raw STEMCELL_WORKDIR=/mnt/stemcells/aws/xen/ubuntu/work/work OS_NAME=ubuntu OS_VERSION=bionic CANDIDATE_BUILD_NUMBER=0000 bundle exec rspec -fd --tag ~exclude_on_aws  --tag ~exclude_on_fips spec/os_image/ubuntu_bionic_spec.rb spec/stemcells/ubuntu_bionic_spec.rb spec/stemcells/go_agent_spec.rb spec/stemcells/aws_spec.rb spec/stemcells/stig_spec.rb spec/stemcells/cis_spec.rb
