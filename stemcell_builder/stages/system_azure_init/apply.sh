#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

packages="python3 python3-pyasn1 python3-setuptools python3-distro python-is-python3 \
cloud-init azure-vm-utils linux-cloud-tools-common linux-cloud-tools-generic"
pkg_mgr install $packages

wala_release=2.15.0.1
wala_expected_sha1=155fd6f326a2bf2ff97b4ea2e2c83dc16a9c1768

curl -L https://github.com/Azure/WALinuxAgent/archive/v${wala_release}.tar.gz > /tmp/wala.tar.gz
sha1=$(cat /tmp/wala.tar.gz | openssl dgst -sha1  | awk 'BEGIN {FS="="}; {gsub(/ /,"",$2); print $2}')
if [ "${sha1}" != "${wala_expected_sha1}" ]; then
  echo "SHA1 of downloaded v${wala_release}.tar.gz ${sha1} does not match expected SHA1 ${wala_expected_sha1}."
  rm -f /tmp/wala.tar.gz
  exit 1
fi

mv -f /tmp/wala.tar.gz $chroot/tmp/wala.tar.gz

run_in_chroot $chroot "
  cd /tmp/
  tar zxvf wala.tar.gz
  cd WALinuxAgent-${wala_release}
  sudo python3 setup.py install --skip-data-files
  cp bin/waagent* /usr/sbin/
  chmod 0755 /usr/sbin/waagent*
  cd /tmp/
  sudo rm -fr WALinuxAgent-${wala_release}
  rm wala.tar.gz
"
mkdir -p $chroot/var/log/azure
cp -f $dir/assets/etc/waagent/waagent.conf $chroot/etc/waagent.conf
cp -f $dir/assets/etc/waagent/walinuxagent.service $chroot/lib/systemd/system/walinuxagent.service
chmod 0644 $chroot/lib/systemd/system/walinuxagent.service
run_in_chroot $chroot "systemctl enable walinuxagent.service"

cat > $chroot/etc/logrotate.d/waagent <<EOS
/var/log/waagent.log {
    monthly
    rotate 6
    notifempty
    missingok
}
EOS

# Setup cloud-init
rm $chroot/etc/cloud/*.cfg
rm $chroot/etc/cloud/cloud.cfg.d/*.cfg
cp -f $dir/assets/etc/cloud-init/cloud.cfg $chroot/etc/cloud/cloud.cfg
cp -f $dir/assets/etc/cloud-init/*-*.cfg $chroot/etc/cloud/cloud.cfg.d/

# Ensures that cloud-init waits until host keys have been regenerated.
mkdir -p $chroot/etc/systemd/system/cloud-config.service.d
cp -f $dir/assets/etc/systemd/system/cloud-config.service.d/firstboot-blocker.conf \
      $chroot/etc/systemd/system/cloud-config.service.d/firstboot-blocker.conf

# this will append the following two relevant lines (plus a few commented out lines)
# to the default-conf:
# >> :syslogtag, isequal, "[CLOUDINIT]" /var/log/cloud-init.log
# >> & stop
# the effect is that cloud-init logs will not be contained in /var/log/syslog

cat $chroot/etc/rsyslog.d/21-cloudinit.conf >> $chroot/etc/rsyslog.d/50-default.conf

# remove the the cloudinit conf file as we have a test explicitly checking for only
# one syslog config file being present

rm $chroot/etc/rsyslog.d/21-cloudinit.conf


# Enable Hyper-V KVP daemon (installed via linux-cloud-tools)
run_in_chroot "$chroot" "systemctl enable hv-kvp-daemon.service"
