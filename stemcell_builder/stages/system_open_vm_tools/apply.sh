#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

function compile_package {
  run_in_chroot $chroot "
    cd /tmp
    apt install -y autoconf \
    libtool \
    libmspack-dev \
    libmspack0 \
    libglib2.0-dev \
    libglib2.0-0 \
    libxmlsec1-dev \
    libxmlsec1\
    libpam0g-dev \
    libpam0g \
    libxmlsec1-openssl
    wget $(curl -s https://api.github.com/repos/vmware/open-vm-tools/releases/latest | jq -r .assets[0].browser_download_url)
    tar xvf $(curl -s https://api.github.com/repos/vmware/open-vm-tools/releases/latest | jq -r .assets[0].name)
    cd $(curl -s https://api.github.com/repos/vmware/open-vm-tools/releases/latest | jq -r .assets[0].name | awk '{gsub(".tar.gz",""); print}')
    autoreconf -i
    ./configure --without-gtk2 --without-gtk3 --without-gtkmm3 --without-gtkmm --without-x
    make
    make install
    ldconfig
    apt remove -y autoconf \
    libtool \
    libmspack-dev \
    libglib2.0-dev \
    libpam0g-dev \
    libxmlsec1-dev
    "
  # Installing files to start the vmtoolsd service and the VGAuthService
  cp $dir/assets/etc/vmware-tools/tools.conf $chroot/etc/vmware-tools/tools.conf
  cp $dir/assets/etc/init.d/open-vm-tools $chroot/etc/init.d/open-vm-tools
  chmod 0755 $chroot/etc/init.d/open-vm-tools
  cp $dir/assets/lib/systemd/system/vgauth.service $chroot/lib/systemd/system/vgauth.service
  cp $dir/assets/lib/systemd/system/open-vm-tools.service $chroot/lib/systemd/system/open-vm-tools.service
  mkdir $chroot/etc/systemd/system/open-vm-tools.service.requires/
  run_in_chroot $chroot "
    ln -s /lib/systemd/system/open-vm-tools.service /etc/systemd/system/multi-user.target.wants/open-vm-tools.service
    ln -s /lib/systemd/system/vgauth.service /etc/systemd/system/open-vm-tools.service.requires/vgauth.service
    "
}

if [[ "${DISTRIB_CODENAME}" == "xenial" ]]; then
  compile_package
else
  # Installation on CentOS requires v7
  pkg_mgr install open-vm-tools
fi
# open-vm-tools installs unwanted fusermount binary
run_in_chroot $chroot "rm -f /usr/bin/fusermount"

# exclude container interface IPs preventing VM interface IPs displaying on vCenter UI
cat >>$chroot/etc/vmware-tools/tools.conf <<EOF
[guestinfo]
exclude-nics=veth*,docker*,virbr*,silk-vtep,s-*,ovs*,erspan*,nsx-container,antrea*,???????????????
EOF

# The above installation adds a PAM configuration with 'nullok' values in it.
# We need to get rid of those as per stig V-38497.
sed -i -r 's/\bnullok[^ ]*//g' $chroot/etc/pam.d/vmtoolsd
