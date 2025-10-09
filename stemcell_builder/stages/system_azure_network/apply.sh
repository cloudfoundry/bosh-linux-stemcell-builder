#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Remove persistent device names so that eth0 comes up as eth0
rm -fr $chroot/etc/udev/rules.d/70-persistent-net.rules

# Context on the need to replace the hostname is here:
# https://github.com/cloudfoundry/bosh/issues/1399
echo -n "bosh-stemcell" > $chroot/etc/hostname

cat >> $chroot/etc/network/interfaces <<EOS
auto eth0
iface eth0 inet dhcp
EOS

# The port 65330 is unusable on Azure
cp $dir/assets/90-azure-sysctl.conf $chroot/etc/sysctl.d
chmod 0644 $chroot/etc/sysctl.d/90-azure-sysctl.conf

# Install SR-IOV VF udev rule to mark network interfaces as unmanaged and set ifalias
cp $dir/assets/10-azure-sriov-unmanaged.rules $chroot/etc/udev/rules.d
chmod 0644 $chroot/etc/udev/rules.d/10-azure-sriov-unmanaged.rules

# Apply the systemd.network configuration, to ignore unmanaged devices
cp $dir/assets/01-azure-sriov-unmanaged.network $chroot/etc/systemd/network
chmod 0644 $chroot/etc/systemd/network/01-azure-sriov-unmanaged.network
