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

# Every file in /var/lib/apt/lists is named for the build-time snapshot mirror
# that the heredoc above just replaced, so apt discards and refetches all of it
# on the first `apt-get update` on a running VM. Shipping it costs ~190MB on
# disk and ~41MB in the stemcell tarball for zero benefit. Same for the binary
# caches, which apt regenerates on demand.
#
# `apt-get clean` first, then the explicit rm: clean can touch cache state
# itself, and only it knows to empty archives/ and archives/partial/.
run_in_chroot "$chroot" "apt-get clean"

# lists/ itself and its partial/ and auxfiles/ subdirectories stay. Apt does
# recreate a missing subdir, but a parent left with the wrong ownership breaks
# `apt-get update` with a confusing permission error, so leave them in place
# rather than deleting and recreating with hand-written modes. lock is kept for
# the same reason. Contents of both subdirs are regenerable and go.
find "$chroot/var/lib/apt/lists" -mindepth 1 \
  ! -name lock ! -name partial ! -name auxfiles -delete

rm -f "$chroot"/var/cache/apt/*.bin