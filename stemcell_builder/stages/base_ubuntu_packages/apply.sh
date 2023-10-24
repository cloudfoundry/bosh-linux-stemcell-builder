#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

debs="libssl-dev lsof strace bind9-host dnsutils tcpdump iputils-arping \
curl wget bison libreadline6-dev rng-tools \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb libcap2-bin libcap2-dev libbz2-dev \
cmake uuid-dev libgcrypt-dev ca-certificates \
scsitools mg htop module-assistant debhelper runit parted \
cloud-guest-utils anacron software-properties-common \
xfsprogs gdisk libpam-cracklib chrony dbus nvme-cli rng-tools fdisk \
ethtool"

if [[ "${DISTRIB_CODENAME}" == 'xenial' ]]; then
  debs="$debs libcurl3 libcurl3-dev module-init-tools"
fi

if [[ "${DISTRIB_CODENAME}" == 'bionic' ]]; then
  debs="$debs  module-init-tools"
fi

if [[ "${DISTRIB_CODENAME}" == 'bionic' || ${DISTRIB_CODENAME} == 'jammy' ]]; then
  debs="$debs gpg-agent libcurl4 libcurl4-openssl-dev resolvconf net-tools ifupdown"

  pkg_mgr purge netplan.io
  run_in_chroot $chroot "
    rm -rf /usr/share/netplan
    rm -rf /etc/netplan
  "

  cp "$(dirname "$0")/assets/systemd-networkd-resolvconf-update.path" "${chroot}/lib/systemd/system/"
  cp "$(dirname "$0")/assets/systemd-networkd-resolvconf-update.service" "${chroot}/lib/systemd/system/"
  run_in_chroot "${chroot}" "systemctl enable systemd-networkd-resolvconf-update.path"
  run_in_chroot "${chroot}" "systemctl enable systemd-networkd-resolvconf-update.service"
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

run_in_chroot $chroot "add-apt-repository ppa:adiscon/v8-stable"
pkg_mgr install "rsyslog rsyslog-gnutls rsyslog-openssl rsyslog-mmjsonparse rsyslog-mmnormalize rsyslog-relp"
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

# Bionic no longer has "runsvdir-start". The equivalent is /etc/runit/2
if [[ ${DISTRIB_CODENAME} == 'bionic' || ${DISTRIB_CODENAME} == 'jammy' ]]; then
  install -m0750 "${chroot}/etc/runit/2" "${chroot}/usr/sbin/runsvdir-start"
fi

cp "$(dirname "$0")/assets/runit.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable runit"
run_in_chroot "${chroot}" "systemctl enable systemd-logind"
run_in_chroot "${chroot}" "systemctl enable systemd-networkd"
run_in_chroot "${chroot}" "systemctl disable systemd-resolved"
pkgs_to_purge="iw mg wireless-regdb"
pkg_mgr purge --auto-remove "$pkgs_to_purge"

exclusions="postfix whoopsie apport"
pkg_mgr purge --auto-remove $exclusions
