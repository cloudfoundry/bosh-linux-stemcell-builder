#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

monit_basename=monit-5.2.5
monit_archive=$monit_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$monit_archive $chroot/$bosh_dir/src

pkg_mgr install "zlib1g-dev"

run_in_bosh_chroot $chroot "
cd src
tar zxvf $monit_archive
cd $monit_basename
./configure --prefix=$bosh_dir --without-ssl CFLAGS="-fcommon"
make -j4 && make install
"

mkdir -p $chroot/$bosh_dir/etc
cp $dir/assets/monitrc $chroot/$bosh_dir/etc/monitrc
chmod 0700 $chroot/$bosh_dir/etc/monitrc

# monit refuses to start without an include file present
mkdir -p $chroot/$bosh_app_dir/monit
touch $chroot/$bosh_app_dir/monit/empty.monitrc

# Monit wrapper script:
mv $chroot/$bosh_dir/bin/monit $chroot/$bosh_dir/bin/monit-actual

cp $dir/assets/monit-access-helper.sh $chroot/$bosh_dir/etc/
cp $dir/assets/monit $chroot/$bosh_dir/bin/monit
chmod +x $chroot/$bosh_dir/bin/monit

# NOBLE_TODO: we need to restrict access to monit API we need to investigate systemds capabilities to do this
# cp $dir/assets/restrict-monit-api-access $chroot/etc/network/if-up.d/restrict-monit-api-access
# chmod +x $chroot/etc/network/if-up.d/restrict-monit-api-access

cp "$(dirname "$0")/assets/monit.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable monit.service"