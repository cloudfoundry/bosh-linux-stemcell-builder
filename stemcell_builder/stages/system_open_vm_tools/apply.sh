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
    libxmlsec1
    wget https://github.com/vmware/open-vm-tools/releases/download/stable-12.1.0/open-vm-tools-12.1.0-20219665.tar.gz
    tar xvf open-vm-tools-12.1.0-20219665.tar.gz
    cd open-vm-tools-12.1.0-20219665
    autoreconf -i
    ./configure --without-pam --without-gtk2 --without-gtk3 --without-gtkmm3 --without-gtkmm --without-x
    make
    make install
    ldconfig
    apt remove -y autoconf \
    libtool \
    libmspack-dev \
    libglib2.0-dev \
    libxmlsec1-dev
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
cat >> $chroot/etc/vmware-tools/tools.conf <<EOF
[guestinfo]
exclude-nics=veth*,docker*,virbr*,silk-vtep,s-*,ovs*,erspan*,nsx-container,antrea*,???????????????
EOF

# The above installation adds a PAM configuration with 'nullok' values in it.
# We need to get rid of those as per stig V-38497.
sed -i -r 's/\bnullok[^ ]*//g' $chroot/etc/pam.d/vmtoolsd
