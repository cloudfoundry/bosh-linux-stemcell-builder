#!/usr/bin/env bash

set -

base_dir=$(readlink -nf $(dirname $0)/../..)
source "$base_dir/lib/prelude_apply.bash"
source "$base_dir/etc/settings.bash"

mkdir -p "$chroot/usr/src/ixgbevf-4.6.1"

tar -xzf "$assets_dir/ixgbevf-4.6.1.tar.gz" \
    -C "$chroot/usr/src/ixgbevf-4.6.1" \
    --strip-components=1

mkdir -p "$chroot/usr/src/ixgbevf-4.1.0-k"

tar -xzf "$assets_dir/ixgbevf-4.1.0-k.tar.gz" \
    -C "$chroot/usr/src/ixgbevf-4.1.0-k" \
    --strip-components=1

echo 'all: $(ixgbevf-objs)' >> $chroot/usr/src/ixgbevf-4.1.0-k/Makefile

# cp $chroot/usr/src/ixgbevf-4.6.1/src/Makefile $chroot/usr/src/ixgbevf-4.1.0-k/

cp $assets_dir/usr/src/ixgbevf-4.1.0-k/dkms.conf $chroot/usr/src/ixgbevf-4.1.0-k/dkms.conf

pkg_mgr install dkms

kernelver=$(ls -rt "$chroot/lib/modules" | tail -1)
# run_in_chroot "$chroot" "dkms -k ${kernelver} add -m ixgbevf -v 4.1.0-k"
run_in_chroot "$chroot" "dkms -k ${kernelver} build -m ixgbevf -v 4.1.0-k"
run_in_chroot "$chroot" "dkms -k ${kernelver} install -m ixgbevf -v 4.1.0-k"

run_in_chroot "$chroot" "dracut --force --kver ${kernelver}"
