#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash
source $base_dir/etc/settings.bash

run_in_chroot $chroot "
subscription-manager register --username=${RHN_USERNAME} --password=${RHN_PASSWORD} --auto-attach

if rct cat-cert /etc/pki/product/69.pem | grep -q rhel-7-server; then
  subscription-manager repos --enable=rhel-7-server-optional-rpms
elif rct cat-cert /etc/pki/product/69.pem | grep -q rhel-8; then
  # NOTE: BaseOS and AppStream contain all software packages, which were available in extras and optional repositories before.
  # see: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/considerations_in_adopting_rhel_8/repositories_considerations-in-adopting-rhel-8
  # > Both repositories are required for a basic RHEL installation, and are available with all RHEL subscriptions.
  subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
  subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
  # > the CodeReady Linux Builder repository is available with all RHEL subscriptions. It provides additional packages for use by developers. Packages included in the CodeReady Linux Builder repository are unsupported.
  subscription-manager repos --enable=codeready-builder-for-rhel-8-x86_64-rpms
else
  echo 'Product certificate from /mnt/rhel/repodata/productid is not for RHEL 7 or RHEL 8 server.'
  echo 'Please ensure you have mounted the RHEL 7 or RHEL 8 Server install DVD at /mnt/rhel.'
  exit 1
fi
"


# Installation on CentOS requires v7
pkg_mgr install open-vm-tools

# open-vm-tools installs unwanted fusermount binary
run_in_chroot $chroot "rm -f /usr/bin/fusermount"

# exclude container interface IPs preventing VM interface IPs displaying on vCenter UI
cat >> $chroot/etc/vmware-tools/tools.conf <<EOF
[guestinfo]
exclude-nics=veth*,docker*,virbr*,silk-vtep,s-*,ovs*,erspan*,nsx-container,antrea*,???????????????
EOF

# The above installation adds a PAM configuration with 'nullok' values in it.
# We need to get rid of those as per stig V-38497.
sed -i -r 's/\bnullok[^ ]*//g' $chroot/etc/pam.d/vmtoolsd
