#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

rm -r $chroot
kiwicompat --prepare $base_dir/stages/base_opensuse --root $chroot

cp /etc/resolv.conf $chroot/etc/resolv.conf
cp $assets_dir/runit.service $chroot/usr/lib/systemd/system/
cp $assets_dir/dkms-2.2.0.3-16.1.noarch.rpm $chroot/tmp
cp $assets_dir/ubuntu-certificates.run $chroot/usr/lib/ca-certificates/update.d/99x_ubuntu_certs.run

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

run_in_chroot $chroot "
sed -i 's/# installRecommends = yes/installRecommends = no/' /etc/zypp/zypper.conf
zypper --gpg-auto-import-keys ref

# systemd bug: https://bugzilla.suse.com/show_bug.cgi?id=1012818
zypper ar http://download.opensuse.org/update/leap/42.2/oss/ update
zypper -n --gpg-auto-import-keys in --from update systemd
zypper -n rr update

groupadd adm
groupadd dip
systemctl enable runit || true # TODO figure out why enable always returns non-zero exit code

rpm -Uhv /tmp/dkms-2.2.0.3-16.1.noarch.rpm
rm /tmp/dkms-2.2.0.3-16.1.noarch.rpm

rm -rf /lib/modules/4.1.12-1-pv/
rm -rf /lib/modules/4.1.12-1-xen/

# Make sure that SSH host keys are generated. By default they are only generated if there is no
# specific HostKey configuration in /etc/ssh/sshd_config
sed -i 's@if .*;@if true;@' /usr/sbin/sshd-gen-keys-start

# Delete the hosts.equiv trust file (STIG V-38491)
rm /etc/hosts.equiv

# Explicitly enable zypper's gpgcheck
echo 'gpgcheck = on' >> /etc/zypp/zypp.conf
"

touch ${chroot}/etc/gshadow

# This is required for the bosh_go_agent stage
mkdir -p $chroot/etc/service/

run_in_chroot $chroot "
  ln -s /etc/sv /service

  # Enable nf_conntrack module
  echo "nf_conntrack" > /etc/modules-load.d/conntrack.conf
"

# Setting locale
case "${stemcell_operating_system_version}" in
  "leap")
    locale_file=/etc/locale.conf
    ;;
  *)
    echo "Unknown openSUSE release: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/${locale_file}

# Apply security rules
truncate -s0 $chroot/etc/motd # CIS-11.1
