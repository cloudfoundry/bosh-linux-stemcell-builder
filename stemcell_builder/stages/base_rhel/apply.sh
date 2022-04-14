#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash
source $base_dir/stages/base_rhel/rhel_functions.bash

mkdir -p $chroot/var/lib/rpm
rpm --root $chroot --initdb

redhat_version="${stemcell_operating_system_version}"
redhat_config_file="custom_rhel_${stemcell_operating_system_version}_yum.conf"

case "${stemcell_operating_system_version}" in
  "7")
    redhat_base_path="/mnt/rhel"
    release_package_url="/mnt/rhel/Packages/redhat-release-server-*.el7.x86_64.rpm"
    epel_package_url="https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm"
    ;;
  "8")
    redhat_base_path="/mnt/rhel/BaseOS"
    release_package_url="/mnt/rhel/BaseOS/Packages/redhat-release-*.el8.x86_64.rpm"
    epel_package_url="http://mirror.centos.org/centos/8/extras/x86_64/os/Packages/epel-release-8-11.el8.noarch.rpm"
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

# STIG: official Red Hat gpg key is installed (stig: V-38476)
# see: https://access.redhat.com/security/team/key
# see: https://dl.fedoraproject.org/pub/epel/
rpm --import $(dirname $0)/assets/RPM-GPG-KEY-RHEL-${stemcell_operating_system_version}
rpm --import $(dirname $0)/assets/RPM-GPG-KEY-RHEL-${stemcell_operating_system_version}-auxiliary
rpm --import $(dirname $0)/assets/RPM-GPG-KEY-EPEL-${stemcell_operating_system_version}

# STIG: gpgcheck must be enabled (stig: V-38483)
rpm -K ${release_package_url}

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

# STIG: gpgcheck must be enabled (stig: V-38483)
# create the OS-specific yum config (referenced below)
if [ ! -f $chroot/$redhat_config_file ]; then
  cp $base_dir/etc/$redhat_config_file $chroot/
fi

# update yum
run_in_chroot $chroot "yum -c /$redhat_config_file update --assumeyes"

# RHSM CLI registration and repo configuration
pkg_mgr "-c /$redhat_config_file install subscription-manager"
rhsm_register
#rhsm_enable_base_repos #redundant
rhsm_enable_dev_repos

# Install required yum 'Groups' (including 'Environment Groups')
pkg_mgr "-c /$redhat_config_file groupinstall Base"
pkg_mgr "-c /$redhat_config_file groupinstall 'Development Tools'"

# NOTE: RHEL 7 & 8 docs both strongly recommend that 1 of the 'Environment Group' packages be installed,
# and the 'Minimal Install' group is the recommended package for systems aiming for the smallest possible OS footprint.
# The 'Server' group would probably be the next most appropriate for a stemcell.
# SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/performing_a_standard_rhel_installation/index#configuring-software-selection_configuring-software-settings
#   > If you are unsure about which packages to install, Red Hat recommends that you select the Minimal Install base environment. Minimal install installs a basic version of Red Hat Enterprise Linux with only a minimal amount of additional software.
# SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-package-selection-x86
#   This is the RHEL 7 equivalent of the previous link.
# SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/performing_an_advanced_rhel_installation/index
#   > If you are not sure what package should be installed, Red Hat recommends you to select the Minimal Install environment. Minimal Install provides only the packages which are essential for running Red Hat Enterprise Linux 8. This will substantially reduce the chance of the system being affected by a vulnerability.
# SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/security_hardening/index#Minimal_install_securing-rhel-during-installation
# SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/security_hardening/index#ref_profiles-not-compatible-with-server-with-gui_deploying-systems-that-are-compliant-with-a-security-profile-immediately-after-an-installation
pkg_mgr "-c /$redhat_config_file groupinstall 'Minimal Install'"
#pkg_mgr "-c /$redhat_config_file groupinstall 'Server'"

# list the available and installed 'groups'
pkg_mgr "-c /$redhat_config_file grouplist"

run_in_chroot $chroot "yum -c /$redhat_config_file clean all"

touch ${chroot}/etc/sysconfig/network # must be present for network to be configured

# readahead-collector was pegging CPU on startup

echo 'READAHEAD_COLLECT="no"' >> ${chroot}/etc/sysconfig/readahead
echo 'READAHEAD_COLLECT_ON_RPM="no"' >> ${chroot}/etc/sysconfig/readahead

# Setting timezone
cp ${chroot}/usr/share/zoneinfo/UTC ${chroot}/etc/localtime || true

# Setting locale
echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/etc/locale.conf
