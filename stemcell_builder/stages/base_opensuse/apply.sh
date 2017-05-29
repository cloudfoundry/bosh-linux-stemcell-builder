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

# Losen pam_limits limits for the vcap user
# That is necessary for properly running the mysql server, for example
echo 'vcap  soft  nproc  4096' >> /etc/security/limits.conf
echo 'vcap  hard  nproc  4096' >> /etc/security/limits.conf

rpm -Uhv /tmp/dkms-2.2.0.3-16.1.noarch.rpm
rm /tmp/dkms-2.2.0.3-16.1.noarch.rpm

rm -rf /lib/modules/4.1.12-1-pv/
rm -rf /lib/modules/4.1.12-1-xen/

# Make sure that SSH host keys are generated. By default they are only generated if there is no
# specific HostKey configuration in /etc/ssh/sshd_config
sed -i 's@if .*;@if true;@' /usr/sbin/sshd-gen-keys-start
"

touch ${chroot}/etc/gshadow

# This is required for the bosh_go_agent stage
mkdir -p $chroot/etc/service/

run_in_chroot $chroot "
  # Install runit from sources
  mkdir -p /package
  chmod 1755 /package
  cd /package

  wget http://smarden.org/runit/runit-2.1.2.tar.gz
  gunzip runit-2.1.2.tar
  tar -xpf runit-2.1.2.tar
  rm runit-2.1.2.tar

  cd admin/runit-2.1.2
  package/install

  install -m0750 /package/admin/runit/etc/2 /sbin/runsvdir-start
  ln -s /etc/sv /service

  # Setup links for runit to /usr/bin so that monit can start it (it only sets up a very basic
  # PATH env variable which doesn't include /usr/local/bin
  ln -s /usr/local/bin/chpst /usr/bin
  ln -s /usr/local/bin/runit /usr/bin
  ln -s /usr/local/bin/runit-init /usr/bin
  ln -s /usr/local/bin/runsv /usr/bin
  ln -s /usr/local/bin/runsvchdir /usr/bin
  ln -s /usr/local/bin/runsvdir /usr/bin
  ln -s /usr/local/bin/sv /usr/bin
  ln -s /usr/local/bin/svlogd /usr/bin
  ln -s /usr/local/bin/utmpset /usr/bin

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
