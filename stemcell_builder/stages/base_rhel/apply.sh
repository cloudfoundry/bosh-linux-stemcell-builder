#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb

case "${stemcell_operating_system_version}" in
  "7")
    redhat_version="7"
    redhat_config_file="custom_rhel_yum.conf"
    redhat_base_path="/mnt/rhel"
    release_package_url="/mnt/rhel/Packages/redhat-release-server-*.el7.x86_64.rpm"
    epel_package_url="https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm"
    ;;
  "8")
    redhat_version="8"
    redhat_config_file="custom_rhel_8_yum.conf"
    redhat_base_path="/mnt/rhel/BaseOS"
    release_package_url="/mnt/rhel/BaseOS/Packages/redhat-release-*.el8.x86_64.rpm"
    epel_package_url="https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-13.el8.noarch.rpm"
    ;;
  *)
    echo "Unknown RHEL version: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

if ! ls $release_package_url 2>&1 >/dev/null; then
  # then no files match the GLOB in `$release_package_url`
  echo "Please mount the RHEL 7 or RHEL 8 install DVD at /mnt/rhel"
  exit 1
fi

rpm --root $chroot --force --nodeps --install ${release_package_url}

cp /etc/resolv.conf $chroot/etc/resolv.conf

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

unshare -m $SHELL <<INSTALL_YUM
  set -x

  mkdir -p /etc/pki
  mount --no-mtab --bind $chroot/etc/pki /etc/pki
  yum --installroot=$chroot -c $base_dir/etc/${redhat_config_file} --assumeyes install yum

INSTALL_YUM

if [ ! -d $chroot/$redhat_base_path/Packages ]; then
  mkdir -p $chroot/mnt/rhel
  mount --bind /mnt/rhel $chroot/mnt/rhel
  add_on_exit "umount $chroot/mnt/rhel"
fi

run_in_chroot $chroot "
rpm --force --nodeps --install ${release_package_url}
rpm --force --nodeps --install ${epel_package_url}
rpm --rebuilddb
"

if [ ! -f $chroot/$redhat_config_file ]; then
  cp $base_dir/etc/$redhat_config_file $chroot/
fi
run_in_chroot $chroot "yum -c /$redhat_config_file update --assumeyes"
run_in_chroot $chroot "yum -c /$redhat_config_file --verbose --assumeyes groupinstall Base"
run_in_chroot $chroot "yum -c /$redhat_config_file --verbose --assumeyes groupinstall 'Development Tools'"
run_in_chroot $chroot "yum -c /$redhat_config_file --verbose --assumeyes install subscription-manager"
run_in_chroot $chroot "yum -c /$redhat_config_file clean all"


# subscription-manager allows access to the Red Hat update server. It detects which repos
# it should allow access to based on the contents of 69.pem.
if [ ! -f $redhat_base_path/repodata/productid ]; then
  echo "Can't find Red Hat product certificate at $redhat_base_path/repodata/productid."
  echo "Please ensure you have mounted the RHEL 7 or RHEL 8 Server install DVD at /mnt/rhel."
  exit 1
fi

mkdir -p $chroot/etc/pki/product
cp $redhat_base_path/repodata/productid $chroot/etc/pki/product/69.pem

mount --bind /proc $chroot/proc
add_on_exit "umount $chroot/proc"

mount --bind /dev $chroot/dev
add_on_exit "umount $chroot/dev"

run_in_chroot $chroot "

subscription-manager register --username=${RHN_USERNAME} --password=${RHN_PASSWORD} --auto-attach

# Configure RHSM package repositories
# SEE: https://access.redhat.com/solutions/265523 (section 'Commonly used repositories')
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

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# readahead-collector was pegging CPU on startup

echo 'READAHEAD_COLLECT="no"' >> ${chroot}/etc/sysconfig/readahead
echo 'READAHEAD_COLLECT_ON_RPM="no"' >> ${chroot}/etc/sysconfig/readahead

# Setting timezone
cp ${chroot}/usr/share/zoneinfo/UTC ${chroot}/etc/localtime || true

# Setting locale
echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/etc/locale.conf
