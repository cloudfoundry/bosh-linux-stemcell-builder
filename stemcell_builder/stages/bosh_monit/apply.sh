#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

monit_basename=monit-5.2.5
monit_archive=$monit_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src

# Unpack outside the chroot rather than with `run_in_bosh_chroot ... tar zxvf`.
# The chroot's own tar is the target OS's binary, and Ubuntu 26.04's x86-64 tar
# cannot extract under Rosetta (ENOSYS, see the ARM64_TAR_FIX note in
# ci/docker/os-image-stemcell-builder/Dockerfile). The builder container's tar
# is known-good, and unpacking a source tarball needs no chroot context.
tar zxf $dir/assets/$monit_archive -C $chroot/$bosh_dir/src

pkg_mgr install "zlib1g-dev libcrypt-dev"

run_in_bosh_chroot $chroot "
cd src/$monit_basename
./configure --prefix=$bosh_dir --without-ssl CFLAGS='-fcommon' LIBS='-lcrypt'
make -j4 && make install
"

mkdir -p $chroot/$bosh_dir/etc
cp $dir/assets/monitrc $chroot/$bosh_dir/etc/monitrc
chmod 0700 $chroot/$bosh_dir/etc/monitrc

# monit refuses to start without an include file present
mkdir -p $chroot/$bosh_app_dir/monit
touch $chroot/$bosh_app_dir/monit/empty.monitrc

cp "$(dirname "$0")/assets/monit.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable monit.service"