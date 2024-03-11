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
xfsprogs gdisk chrony dbus nvme-cli rng-tools fdisk \
ethtool libpam-pwquality"

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

pkg_mgr install $debs

# NOBLE_TODO: adiscon repo does not have noble packages yet
# run_in_chroot $chroot "add-apt-repository ppa:adiscon/v8-stable"
# pkg_mgr install "rsyslog rsyslog-gnutls rsyslog-openssl rsyslog-mmjsonparse rsyslog-mmnormalize rsyslog-relp"
pkg_mgr install "rsyslog rsyslog-gnutls rsyslog-openssl rsyslog-relp"


# Bionic no longer has "runsvdir-start". The equivalent is /etc/runit/2
install -m0750 "${chroot}/etc/runit/2" "${chroot}/usr/sbin/runsvdir-start"

cp "$(dirname "$0")/assets/runit.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable runit"
run_in_chroot "${chroot}" "systemctl enable systemd-logind"
run_in_chroot "${chroot}" "systemctl enable systemd-networkd"
pkgs_to_purge="iw mg wireless-regdb"
pkg_mgr purge --auto-remove "$pkgs_to_purge"

exclusions="postfix whoopsie apport"
pkg_mgr purge --auto-remove $exclusions
