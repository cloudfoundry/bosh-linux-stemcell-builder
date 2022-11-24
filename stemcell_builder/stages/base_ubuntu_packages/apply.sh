#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

debs="libssl-dev lsof strace bind9-host dnsutils tcpdump iputils-arping \
curl wget bison libreadline6-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb libcap2-bin libcap2-dev libbz2-dev \
cmake uuid-dev libgcrypt-dev ca-certificates \
scsitools mg htop module-assistant debhelper runit parted \
cloud-guest-utils anacron software-properties-common \
xfsprogs gdisk libpam-cracklib chrony module-init-tools dbus \
nvme-cli ethtool"

if [[ "${DISTRIB_CODENAME}" == 'xenial' ]]; then
  debs="$debs  libcurl3 libcurl3-dev"
fi

if [[ "${DISTRIB_CODENAME}" == 'bionic' ]]; then
  debs="$debs gpg-agent libcurl4 openresolv ifupdown net-tools"
fi

if is_ppc64le; then
  debs="$debs \
libreadline-dev libtool texinfo ppc64-diag libffi-dev \
libruby bundler libgmp-dev libgmp3-dev libmpfr-dev libmpc-dev"
fi

pkg_mgr install $debs

if [[ "${DISTRIB_CODENAME}" == 'trusty' ]]; then
  run_in_chroot $chroot "
    cd /tmp

    wget http://archive.ubuntu.com/ubuntu/pool/universe/n/nvme-cli/nvme-cli_0.5-1_amd64.deb
    echo 'd2eee79dd72d1102c2c6e685f134b82f98768041eca7e1ae2a3575ce36a6bbee  nvme-cli_0.5-1_amd64.deb' | shasum -a 256 -c -
    dpkg -i nvme-cli_0.5-1_amd64.deb
    rm -f nvme-cli_0.5-1_amd64.deb
  "
fi

if ! is_ppc64le; then
  run_in_chroot $chroot "add-apt-repository ppa:adiscon/v8-stable"
  pkg_mgr install "rsyslog rsyslog-gnutls rsyslog-mmjsonparse rsyslog-relp"

  run_in_chroot $chroot "
    cd /tmp

    if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
      wget http://security.ubuntu.com/ubuntu/pool/main/libg/libgcrypt11/libgcrypt11_1.5.3-2ubuntu4.6_amd64.deb
      echo '39ab5032aa4597366d2c33f31e06ba91ba2ad79c8f68aff8ffcfab704b256a2c  libgcrypt11_1.5.3-2ubuntu4.6_amd64.deb' | shasum -a 256 -c -

      wget http://security.ubuntu.com/ubuntu/pool/main/g/gnutls26/libgnutls26_2.12.23-12ubuntu2.8_amd64.deb
      echo '75417c39414ab8919ee02eb4f1761c412d92c10a9ac1839fcd1e04bcfc85f607  libgnutls26_2.12.23-12ubuntu2.8_amd64.deb' | shasum -a 256 -c -

      dpkg -i libgcrypt11_1.5.3-2ubuntu4.6_amd64.deb \
        libgnutls26_2.12.23-12ubuntu2.8_amd64.deb

      rm *.deb
    fi
  "
else
  pkg_mgr install "libsystemd-journal-dev libestr-dev libjson0 libjson0-dev uuid-dev python-docutils libcurl4-openssl-dev"

  function check_md5 {
    result=`run_in_chroot ${chroot} "cd /tmp; md5sum ${1}"`
    if [ "$result" == "$2  $1" ]; then
      echo "Checksum is correct"
    else
      echo "Checksum error for $1"
      exit 1
    fi
  }

  run_in_chroot $chroot "
    cd /tmp
    # on ppc64le compile from source as the .deb packages are not available
    # from the repo above
    wget http://download.rsyslog.com/liblogging/liblogging-1.0.5.tar.gz
    wget http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-8.15.0.tar.gz
    wget http://download.rsyslog.com/librelp/librelp-1.2.9.tar.gz
  "

  check_md5 liblogging-1.0.5.tar.gz 44b8ce2daa1bfb84c9feaf42f9925fd7
  check_md5 rsyslog-8.15.0.tar.gz 3fab1c48e8d8111d4cc412482e2fe39d
  check_md5 librelp-1.2.9.tar.gz 6df8123486b6aafde90c64a0a5951892

  run_in_chroot $chroot "
    cd /tmp
    tar xvfz liblogging-1.0.5.tar.gz
    cd liblogging-1.0.5
    ./configure --disable-man-pages --prefix=/usr
    make && sudo make install
    cd ..

    tar xvfz librelp-1.2.9.tar.gz
    cd librelp-1.2.9
    ./configure --prefix=/usr
    make && sudo make install
    cd ..

    tar xvfz rsyslog-8.15.0.tar.gz
    cd rsyslog-8.15.0
    ./configure --enable-mmjsonparse --enable-gnutls --enable-relp --prefix=/usr
    make && sudo make install

    cd /tmp
    rm -rf liblogging-* librelp-* rsyslog-*
  "
fi

# Bionic no longer has "runsvdir-start". The equivalent is /etc/runit/2
if [ ${DISTRIB_CODENAME} == 'bionic' ]; then
  install -m0750 "${chroot}/etc/runit/2" "${chroot}/usr/sbin/runsvdir-start"
fi

cp "$(dirname "$0")/assets/runit.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable runit"
run_in_chroot "${chroot}" "systemctl enable systemd-logind"
pkgs_to_purge="crda iw mg wireless-crda wireless-regdb"
pkg_mgr purge --auto-remove "$pkgs_to_purge"
run_in_chroot "${chroot}" "systemctl disable chrony"

exclusions="postfix whoopsie apport"
pkg_mgr purge --auto-remove $exclusions
