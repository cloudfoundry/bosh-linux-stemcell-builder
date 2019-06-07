#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# cd $assets_dir/openssl

# cd openssl-1.1.1c

# mkdir -p $chroot/opt/openssl

mkdir -p $chroot/$bosh_dir/src
cp -r $assets_dir/openssl/openssl.tar.gz $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf openssl.tar.gz
cd openssl-1.1.1c
./config --prefix=/opt/openssl --openssldir=/opt/openssl
make
make install
"

# TODO: inject version???
# TODO: clean up source
