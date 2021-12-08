#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mount --bind /sys "$chroot/sys"
add_on_exit "umount $chroot/sys"

cat > "$chroot/etc/apt/sources.list" <<EOS
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME main universe multiverse
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME-updates main universe multiverse
deb http://security.ubuntu.com/ubuntu $DISTRIB_CODENAME-security main universe multiverse
EOS

# Upgrade systemd/upstart first, to prevent it from messing up our stubs and starting daemons anyway
pkg_mgr install systemd

pkg_mgr dist-upgrade

# initscripts messes with /dev/shm -> /run/shm and can create self-referencing symbolic links
# revert /run/shm back to a regular directory (symlinked to by /dev/shm)
rm -rf "$chroot/run/shm"
mkdir -p "$chroot/run/shm"
