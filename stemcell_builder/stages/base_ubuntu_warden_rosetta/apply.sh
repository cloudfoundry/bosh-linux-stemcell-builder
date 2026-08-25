#!/usr/bin/env bash

# Warden stemcell stage for running under Rosetta x86_64 emulation on an arm64
# kernel (Colima/Lima on Apple Silicon).
#
# Rosetta does not translate every syscall, and its JIT needs writable+executable
# memory, so some x86-64 binaries cannot run. Each is replaced with the arm64
# build of the same package version, which runs natively on the arm64 kernel:
#
#   tar          cannot extract anything (ENOSYS)
#   systemd      needs pidfd_open / pidfd_send_signal
#   unix_chkpwd  AppArmor denies it the Rosetta interpreter, breaking PAM
#   auditd       cannot satisfy Type=forking + MemoryDenyWriteExecute
#   logrotate    killed by MemoryDenyWriteExecute
#
# arm64 libraries install alongside the x86-64 ones under
# /lib/aarch64-linux-gnu/ via multiarch; the arm64 binaries find them by RPATH.
#
# See docs/rosetta-stemcell-variant.md for the detail behind each entry.
#
# Inserted into warden_stages only when the OS variant is "rosetta"
# (rake ... ubuntu,resolute-rosetta,...); other builds are unaffected.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# ---------------------------------------------------------------------------
# Part 1: arm64 foreign architecture and runtime libraries
# ---------------------------------------------------------------------------

# Enable arm64 as a foreign architecture so apt can resolve arm64 packages.
run_in_chroot $chroot "dpkg --add-architecture arm64"
run_in_chroot $chroot "apt-get update"

# Install arm64 runtime libraries needed by the arm64 binaries installed below
# (systemd in Part 3; unix_chkpwd, auditd and logrotate in Part 4 — auditd needs
# libauparse, logrotate needs libpopt).
# These install into /lib/aarch64-linux-gnu/ and /usr/lib/aarch64-linux-gnu/,
# coexisting safely with the existing amd64 libraries.
# libc6:arm64 also places /lib/ld-linux-aarch64.so.1 (the arm64 ELF interpreter).
arm64_libs="libc6:arm64 \
  libselinux1:arm64 \
  libcrypt1:arm64 \
  libgcrypt20:arm64 \
  libblkid1:arm64 \
  libcap2:arm64 \
  liblz4-1:arm64 \
  libzstd1:arm64 \
  libmount1:arm64 \
  libseccomp2:arm64 \
  libkmod2:arm64 \
  libaudit1:arm64 \
  libpam0g:arm64 \
  libacl1:arm64 \
  libssl3t64:arm64 \
  libp11-kit0:arm64 \
  liblzma5:arm64 \
  libgpg-error0:arm64 \
  libauparse0t64:arm64 \
  libpopt0:arm64"

run_in_chroot $chroot "apt-get install --no-install-recommends --assume-yes $arm64_libs"

# ---------------------------------------------------------------------------
# Part 2: arm64 tar
# ---------------------------------------------------------------------------

# This has to happen before the systemd debs below, because extracting those
# uses the chroot's own tar — and Ubuntu 26.04's x86-64 GNU tar
# (1.35+dfsg-4ubuntu0.4) cannot extract anything under Rosetta: every file it
# creates fails with "Cannot open: Function not implemented" (ENOSYS), because
# tar issues a syscall Rosetta does not translate. Ubuntu 24.04's tar is
# unaffected, so this is new in 26.04. The arm64 build of the same version works
# because it runs natively on the arm64 kernel. It is also the only tool in the
# base image with this problem — gzip, xz, zstd, cpio, rsync and coreutils are
# all fine.
#
# It matters at runtime too, not just during the build: the BOSH agent shells
# out to tar to unpack every compiled package and release blob it downloads, so
# a stemcell with a broken tar cannot run a single deployment.
#
# dpkg has its own built-in tar reader and does not call GNU tar to unpack debs,
# so apt keeps working regardless; only direct tar invocations are affected
# (including `dpkg -x`, which does shell out to GNU tar).
#
# `apt-get install tar:arm64` cannot be used: tar is Multi-Arch-incompatible and
# tar:amd64 declares Conflicts: tar:arm64. Download and swap the binary in by
# hand instead, the same way the systemd binaries are handled below.
run_in_chroot $chroot "
  mkdir -p /tmp/arm64-tar
  cd /tmp/arm64-tar
  apt-get download tar:arm64
"

# Unpack from outside the chroot: the chroot's own tar is the broken binary we
# are about to replace, so it cannot be used to extract its own replacement.
# The builder container's tar is known-good (see ARM64_TAR_FIX in
# ci/docker/os-image-stemcell-builder/Dockerfile).
mkdir -p "$chroot/tmp/arm64-tar/root"
dpkg-deb --fsys-tarfile "$chroot"/tmp/arm64-tar/tar_*_arm64.deb \
  | tar -x -C "$chroot/tmp/arm64-tar/root"

# Keep the x86-64 binary as tar.amd64 for debugging and so the swap is obvious
# to anyone inspecting the stemcell.
mv "$chroot/usr/bin/tar" "$chroot/usr/bin/tar.amd64"
install -m 0755 "$chroot/tmp/arm64-tar/root/usr/bin/tar" "$chroot/usr/bin/tar"
rm -rf "$chroot/tmp/arm64-tar"

# Fail loudly if the replacement cannot actually extract. Everything below
# depends on it, and a silently broken tar would otherwise only surface much
# later as an unexplained deployment failure.
run_in_chroot $chroot "
  set -e
  rm -rf /tmp/tar-selftest
  mkdir -p /tmp/tar-selftest/src /tmp/tar-selftest/out
  echo rosetta > /tmp/tar-selftest/src/probe
  tar -czf /tmp/tar-selftest/probe.tgz -C /tmp/tar-selftest src
  tar -xzf /tmp/tar-selftest/probe.tgz -C /tmp/tar-selftest/out
  grep -q rosetta /tmp/tar-selftest/out/src/probe
  rm -rf /tmp/tar-selftest
"

# ---------------------------------------------------------------------------
# Part 3: arm64 systemd binaries
# ---------------------------------------------------------------------------

# Download arm64 systemd debs without installing.
# `apt-get install systemd:arm64` would conflict with systemd:amd64 because
# systemd does not carry Multi-Arch: same. Download and extract manually instead.
# systemd-resolved ships in a separate Ubuntu package from the main systemd deb.
run_in_chroot $chroot "
  mkdir -p /tmp/arm64-debs
  cd /tmp/arm64-debs
  apt-get download systemd:arm64 libsystemd-shared:arm64 systemd-resolved:arm64
"

# Extract the debs into staging directories.
run_in_chroot $chroot "
  dpkg -x /tmp/arm64-debs/systemd_*_arm64.deb           /tmp/arm64-debs/systemd
  dpkg -x /tmp/arm64-debs/libsystemd-shared_*_arm64.deb /tmp/arm64-debs/libsystemd-shared
  dpkg -x /tmp/arm64-debs/systemd-resolved_*_arm64.deb  /tmp/arm64-debs/systemd-resolved
"

# Install arm64 private shared libraries into the arm64-specific path.
# The arm64 systemd binary's RPATH points to /usr/lib/aarch64-linux-gnu/systemd/.
run_in_chroot $chroot "
  mkdir -p /usr/lib/aarch64-linux-gnu/systemd
  cp /tmp/arm64-debs/libsystemd-shared/usr/lib/aarch64-linux-gnu/systemd/libsystemd-*.so \
     /usr/lib/aarch64-linux-gnu/systemd/
"

# Replace x86_64 systemd service daemons with arm64 equivalents.
# Only daemons in /usr/lib/systemd/ are replaced; user-facing CLI tools in
# /usr/bin/ (systemctl, journalctl, etc.) are deliberately left as x86-64.
# Those tools communicate with PID1 over D-Bus and never call pidfd themselves,
# so they work correctly under Rosetta. Keeping them x86-64 also allows the
# build-time RSpec suite to execute them inside the x86-64 chroot environment.
# Symlinks in /usr/lib/systemd/ (e.g. systemd-udevd@ -> ../../bin/udevadm) are
# skipped by -type f so they continue to point at their existing targets.
run_in_chroot $chroot "
  # All regular-file daemons from the main systemd package (includes PID1).
  # On Ubuntu 22.04+ (UsrMerge), /lib -> usr/lib, so the deb ships binaries
  # at usr/lib/systemd/ rather than lib/systemd/.
  find /tmp/arm64-debs/systemd/usr/lib/systemd/ -maxdepth 1 -type f \
    | xargs -I{} cp {} /usr/lib/systemd/

  # systemd-resolved is packaged separately on Ubuntu.
  cp /tmp/arm64-debs/systemd-resolved/usr/lib/systemd/systemd-resolved \
     /usr/lib/systemd/systemd-resolved
"

# Clean up staging area.
run_in_chroot $chroot "rm -rf /tmp/arm64-debs"

# ---------------------------------------------------------------------------
# Part 4: arm64 userland binaries
# ---------------------------------------------------------------------------

# swap_arm64_binary <apt-package> <absolute-path> [group]
#
# None of these packages carry Multi-Arch: same, so `apt-get install <pkg>:arm64`
# would conflict with the amd64 package; download and swap by hand instead. The
# x86-64 build is kept as <path>.amd64, matching tar.amd64 above.
swap_arm64_binary() {
  local pkg="$1" path="$2" group="${3:-}"
  local stage="/tmp/arm64-swap"

  run_in_chroot $chroot "
    set -e
    rm -rf $stage
    mkdir -p $stage
    cd $stage
    apt-get download ${pkg}:arm64
    dpkg -x $stage/${pkg}_*_arm64.deb $stage/root
  "

  if [ ! -f "$chroot$stage/root$path" ]; then
    echo "ERROR: ${pkg}:arm64 does not ship $path" >&2
    exit 1
  fi

  mv "$chroot$path" "$chroot${path}.amd64"
  install -m 0755 "$chroot$stage/root$path" "$chroot$path"
  [ -n "$group" ] && run_in_chroot $chroot "chown root:$group $path"
  run_in_chroot $chroot "rm -rf $stage"

  # Fail loudly if the swap did not land. A silently-still-x86-64 binary would
  # only resurface much later as an unexplained runtime failure.
  run_in_chroot $chroot "
    set -e
    head -c 20 $path | grep -qa 'ELF' || { echo '$path is not an ELF binary' >&2; exit 1; }
    # e_machine at offset 18 is 183 (EM_AARCH64) for arm64, 62 for x86-64.
    arch_byte=\$(od -An -tu1 -j18 -N1 $path | tr -d ' ')
    if [ \"\$arch_byte\" != '183' ]; then
      echo \"ERROR: $path is not arm64 (e_machine=\$arch_byte)\" >&2
      exit 1
    fi
  "
}

# pam_unix forks /usr/sbin/unix_chkpwd to read /etc/shadow. An AppArmor profile
# attached by path to /{,usr/}{,s}bin/unix_chkpwd — loaded on the Lima VM and
# enforced by the shared kernel, so it applies inside containers too — grants no
# access to the Rosetta interpreter, which an x86-64 build needs in order to exec:
#
#   apparmor="DENIED" profile="unix-chkpwd" name="mnt/lima-rosetta/rosetta"
#   pam_unix(sshd:account): unix_chkpwd abnormal exit: 5
#
# The interpreter cannot be allow-listed: AppArmor reports it as a disconnected
# path (note the missing leading slash), which needs flags=(attach_disconnected)
# on the profile header and so cannot come from an /etc/apparmor.d/local/ include.
#
# Mode stays 0755, not the 2755 the deb ships: restrict_binary_setuid strips
# setgid outside the allowlist asserted in stemcells/ubuntu_spec.rb. su is
# setuid-root and sshd is already privileged when they fork the helper, which is
# how it reads /etc/shadow at 0400 root:root.
swap_arm64_binary libpam-modules-bin /usr/sbin/unix_chkpwd shadow

# auditd.service is Type=forking with a PIDFile and MemoryDenyWriteExecute=true;
# an x86-64 build can satisfy neither under Rosetta. Only the daemon is swapped:
# auditctl and augenrules cannot work in a container on any architecture, which
# is why base_warden skips audit-rules.service.
swap_arm64_binary auditd /usr/sbin/auditd

# logrotate.service ships MemoryDenyWriteExecute=true, which kills the x86-64
# binary outright (Result=signal).
swap_arm64_binary logrotate /usr/sbin/logrotate

# ---------------------------------------------------------------------------
# Part 5: binfmt_misc
# ---------------------------------------------------------------------------

# systemd-binfmt rewrites /proc/sys/fs/binfmt_misc, where Lima registers the
# Rosetta handler; letting it run risks deregistering Rosetta and leaving no
# x86-64 binary in the container executable.
run_in_chroot "$chroot" "systemctl mask systemd-binfmt.service"
