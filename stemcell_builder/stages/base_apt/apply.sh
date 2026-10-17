#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mount --bind /sys "$chroot/sys"
add_on_exit "umount $chroot/sys"

# Ubuntu serves non-amd64 architectures (e.g. arm64) from the ports mirror
# (ports.ubuntu.com/ubuntu-ports) rather than archive/security.ubuntu.com.
# stemcell_target_arch derives the arch from the bootstrapped chroot, so this
# works regardless of how build settings are propagated. Defaults to the amd64
# mirrors for amd64/unknown so existing builds are unchanged.
if [ "$(stemcell_target_arch)" == "arm64" ]; then
  apt_archive_mirror="http://ports.ubuntu.com/ubuntu-ports"
  apt_security_mirror="http://ports.ubuntu.com/ubuntu-ports"
else
  apt_archive_mirror="http://archive.ubuntu.com/ubuntu"
  apt_security_mirror="http://security.ubuntu.com/ubuntu"
fi

# check if current git branch is a tag and use snapshot date from the last commit message in that tag
if [ -n "${BUILD_TIME:-}" ]; then
  cat > "$chroot/etc/apt/sources.list" <<EOS
  deb http://snapshot.ubuntu.com/ubuntu/${BUILD_TIME} $DISTRIB_CODENAME main universe multiverse
  deb http://snapshot.ubuntu.com/ubuntu/${BUILD_TIME} $DISTRIB_CODENAME-updates main universe multiverse
  deb http://snapshot.ubuntu.com/ubuntu/${BUILD_TIME} $DISTRIB_CODENAME-security main universe multiverse
EOS
else
  cat > "$chroot/etc/apt/sources.list" <<EOS
  deb ${apt_archive_mirror} $DISTRIB_CODENAME main universe multiverse
  deb ${apt_archive_mirror} $DISTRIB_CODENAME-updates main universe multiverse
  deb ${apt_security_mirror} $DISTRIB_CODENAME-security main universe multiverse
EOS
fi

# Upgrade systemd/upstart first, to prevent it from messing up our stubs and starting daemons anyway
pkg_mgr install systemd

pkg_mgr dist-upgrade

# initscripts messes with /dev/shm -> /run/shm and can create self-referencing symbolic links
# revert /run/shm back to a regular directory (symlinked to by /dev/shm)
rm -rf "$chroot/run/shm"
mkdir -p "$chroot/run/shm"
