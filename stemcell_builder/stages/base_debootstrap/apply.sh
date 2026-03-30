#!/usr/bin/env bash

set -e

base_dir="$(readlink -nf "$(dirname "$0")"/../..)"
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"

: "${base_debootstrap_suite:?}"
: "${base_debootstrap_arch:?}"
: "${assets_dir:?}"

# Bootstrap the base system
echo "Running debootstrap"

# Clean up any leftover state from previous failed runs. When debootstrap fails
# it tries to rm -rf the chroot, but if /proc is mounted it cannot remove the
# proc virtual files, leaving a partially populated directory that would trip up
# a subsequent run.
for _mnt in proc sys dev/pts dev; do
  umount -l "$chroot/$_mnt" 2>/dev/null || true
done
rm -rf "$chroot"
mkdir -p "$chroot"

# Detect Rosetta x86_64 translation (Apple Silicon host running amd64 container).
_rosetta=false
if grep -q '/rosetta' /proc/self/maps 2>/dev/null; then
  _rosetta=true
fi

# Work around Rosetta 2 / Apple Silicon compatibility issues with debootstrap.
#
# When building inside a Docker container on an ARM64 host with Rosetta x86_64
# translation, debootstrap hits two problems:
#
#   1. detect_container() sees /.dockerenv and sets CONTAINER=docker, which
#      triggers setup_proc_symlink during first_stage_install.  That function
#      does `rm -rf $TARGET/proc; ln -s /proc $TARGET/proc`, creating a
#      circular symlink that causes ELOOP when Rosetta reads /proc/self/exe.
#
#   2. setup_proc() during second_stage_install unmounts $TARGET/proc and then
#      runs `in_target mount -t proc proc /proc`.  That executes the x86_64
#      mount binary through Rosetta, which needs /proc/self/exe — but /proc
#      was just unmounted.
#
# Fix — no debootstrap patching required:
#
#   (a) Temporarily hide /.dockerenv so detect_container() does not set
#       CONTAINER=docker.  This prevents setup_proc_symlink entirely.
#
#   (b) Mount proc in the chroot *twice*: once as a real procfs, then a bind
#       mount on top.  When setup_proc()'s `umount` runs, it peels the bind
#       layer off but the underlying procfs survives, keeping /proc/self/exe
#       available for Rosetta throughout the entire second stage.
_dockerenv_hidden=false
if [ "$_rosetta" = true ]; then
  if [ -e /.dockerenv ]; then
    mv /.dockerenv /.dockerenv.hidden
    _dockerenv_hidden=true
  fi

  mkdir -p "$chroot/proc"
  mount -t proc proc "$chroot/proc"
  mount --bind "$chroot/proc" "$chroot/proc"
fi

cleanup_debootstrap() {
  if [ "$_rosetta" = true ]; then
    umount "$chroot/proc" 2>/dev/null || true
    umount "$chroot/proc" 2>/dev/null || true
  fi
  if [ "$_dockerenv_hidden" = true ]; then
    mv /.dockerenv.hidden /.dockerenv 2>/dev/null || true
  fi
}
trap cleanup_debootstrap EXIT

debootstrap --arch="$base_debootstrap_arch" "$base_debootstrap_suite" "$chroot" ""

cleanup_debootstrap
trap - EXIT

# See https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm -f "$chroot"/var/lib/apt/lists/{archive,security,lock}*

# Copy over some other system assets
# Networking...
cp "$assets_dir/etc/hosts" "$chroot/etc/hosts"

# Timezone
cp "$assets_dir/etc/timezone" "$chroot/etc/timezone"

run_in_chroot "$chroot" "dpkg-reconfigure -fnoninteractive -pcritical tzdata"

# Locale
cp "$assets_dir/etc/default/locale" "$chroot/etc/default/locale"
run_in_chroot "$chroot" "locale-gen en_US.UTF-8"
run_in_chroot "$chroot" "dpkg-reconfigure -fnoninteractive locales"
