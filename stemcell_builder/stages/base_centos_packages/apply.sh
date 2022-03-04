#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

case "${stemcell_operating_system_version}" in
  "7")
    init_package_name="systemd"
    version_specific_packages="bind9-host dnsutils iputils-arping \
    libcurl3 libcurl3-dev \
    nfs-common apparmor-utils \
    libncurses5-devs \
    libaio1 libcap2-bin"
    ;;
  "8")
    init_package_name="systemd"
    version_specific_packages="bind bind-utils iputils \
    libcurl libcurl-devel \
    nfs-utils \
    ncurses-devel \
    libaio libcap"
    ;;
  *)
    echo "Unknown centos version: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

# The CentOS 6 script upgraded upstart first, "to prevent it from messing up our stubs and starting daemons anyway"
# so we'll upgrade systemd for possibly the same reason
pkg_mgr install ${init_package_name}

# Install base packages needed by both the warden and bosh
packages="openssl-devel libyaml-devel lsof \
	strace tcpdump \
	curl wget bison \
	readline-devel \
	libxml2 libxml2-devel libxslt libxslt-devel \
	dhclient \
	zip unzip \
	flex psmisc iptables sysstat \
	rsync openssh-server traceroute \
	gdb libcap-devel bzip2-devel \
	cmake sudo libuuid-devel parted NetworkManager e2fsprogs cloud-utils-growpart \
	xfsprogs gdisk nvme-cli \
	nmap-ncat"

pkg_mgr install ${packages} ${version_specific_packages}

if [ "${stemcell_operating_system_version}" == "8" ]; then
    pkg_mgr install perl-Pod-Checker perl-Pod-Html python3
    run_in_chroot $chroot "
      yum -y groupinstall 'Development Tools'
      wget https://launchpad.net/apparmor/3.0/3.0.3/+download/apparmor-3.0.3.tar.gz
      wget https://rpmfind.net/linux/centos/8-stream/PowerTools/x86_64/os/Packages/libstdc++-static-8.5.0-4.el8_5.x86_64.rpm
      yum install -y libstdc++-static-8.5.0-4.el8_5.x86_64.rpm
      rm libstdc++-static-8.5.0-4.el8_5.x86_64.rpm
      tar xzf apparmor-3.0.3.tar.gz
      cd apparmor-3.0.3/libraries/libapparmor/
      ./configure
      make
      cd ../../parser
      make arch
      cd ../utils
      make
      make install
      cd ..
      rm -rf apparmor-3.0.3.tar.gz apparmor-3.0.3
      chmod 0755 /bin/aa-easyprof /usr/bin/aa-easyprof
    "
fi		

# Install runit
runit_version=runit-2.1.1
if ! pkg_exists ${runit_version}; then
  pkg_mgr install "rpm-build rpmdevtools glibc-static"
  cookbook_release=1.2.0
  run_in_chroot $chroot "
    curl -L https://github.com/opscode-cookbooks/runit/archive/v${cookbook_release}.tar.gz > /tmp/v${cookbook_release}.tar.gz
    tar -C /tmp -xvf /tmp/v${cookbook_release}.tar.gz
    tar -C /tmp -xvf /tmp/runit-${cookbook_release}/files/default/${runit_version}.tar.gz
    cd /tmp/${runit_version}
    ./build.sh
    rpm -i /rpmbuild/RPMS/${runit_version}.rpm
  "
fi

# arrange for runit to start when the system boots
if [ "${init_package_name}" == "systemd" ]; then
  cp $(dirname $0)/assets/runit.service ${chroot}/usr/lib/systemd/system/
  run_in_chroot ${chroot} "systemctl enable runit"
  run_in_chroot ${chroot} "systemctl enable NetworkManager"
fi

# we need newer rsyslog; this comes from the upstream project's own repo
echo ${stemcell_operating_system_version} >${chroot}/etc/yum/vars/releasevernum
cp $(dirname $0)/assets/rsyslog.repo ${chroot}/etc/yum.repos.d/
pkg_mgr install "rsyslog rsyslog-relp rsyslog-mmjsonparse rsyslog-gnutls"
run_in_chroot $chroot "yum update --assumeyes"

if [ "${stemcell_operating_system_version}" != "8" ]; then
	run_in_chroot $chroot "rpm -e quota rpcbind"
fi

exclusions="mlocate firewalld rpcbind"
pkg_mgr erase $exclusions
