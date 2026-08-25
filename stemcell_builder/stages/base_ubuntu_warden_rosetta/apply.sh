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
#
# The stage is host-architecture agnostic: it never executes an arm64 binary as
# part of doing its work, so it runs on an x86-64 CI worker as well as on Apple
# Silicon. Everything is downloaded and extracted first and the binaries are
# swapped in at the end; extraction uses the builder container's tar rather than
# the chroot's, because whichever architecture the chroot's tar is, it is
# unrunnable on one of the two hosts. The execution-based self-test at the end is
# the one part that needs an arm64-capable kernel, and it skips loudly when the
# host has none.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

debs_dir=/tmp/arm64-debs
debs_root="$chroot$debs_dir/root"

# ---------------------------------------------------------------------------
# Part 1: arm64 foreign architecture and runtime libraries
# ---------------------------------------------------------------------------

# Enable arm64 as a foreign architecture so apt can resolve arm64 packages.
run_in_chroot $chroot "dpkg --add-architecture arm64"
run_in_chroot $chroot "apt-get update"

# Install arm64 runtime libraries needed by the arm64 binaries installed below
# (systemd in Part 4; unix_chkpwd, auditd and logrotate in Part 5 — auditd needs
# libauparse, logrotate needs libpopt).
# These install into /lib/aarch64-linux-gnu/ and /usr/lib/aarch64-linux-gnu/,
# coexisting safely with the existing amd64 libraries.
# libc6:arm64 also places /lib/ld-linux-aarch64.so.1 (the arm64 ELF interpreter).
#
# apt-get install is safe here even though nothing arm64 can run yet: dpkg
# unpacks with its own built-in tar reader, and none of these packages run arm64
# maintainer scripts.
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
# Part 2: download every arm64 deb that gets swapped in by hand
# ---------------------------------------------------------------------------

# None of these packages carry Multi-Arch: same, so `apt-get install <pkg>:arm64`
# conflicts with the installed amd64 package (tar:amd64 declares an explicit
# Conflicts: tar:arm64). Download the debs and swap the binaries out of them
# instead. systemd-resolved and libsystemd-shared ship separately from the main
# systemd deb; unix_chkpwd comes from libpam-modules-bin.
arm64_packages="tar \
  systemd \
  libsystemd-shared \
  systemd-resolved \
  libpam-modules-bin \
  auditd \
  logrotate"

arm64_download_list=""
for pkg in $arm64_packages; do
  arm64_download_list="$arm64_download_list ${pkg}:arm64"
done

run_in_chroot $chroot "
  rm -rf $debs_dir
  mkdir -p $debs_dir
  cd $debs_dir
  apt-get download $arm64_download_list
"

# ---------------------------------------------------------------------------
# Part 3: extract them, from outside the chroot
# ---------------------------------------------------------------------------

# `dpkg -x` inside the chroot shells out to GNU tar, so it would run whichever
# tar the chroot has — the x86-64 one that cannot extract under Rosetta, or the
# arm64 one that cannot execute on an x86-64 worker. dpkg-deb + the builder
# container's tar is correct on both hosts.
extract_deb() {
  local pkg="$1"
  local dest="$debs_root/$pkg"

  mkdir -p "$dest"
  dpkg-deb --fsys-tarfile "$chroot$debs_dir/${pkg}"_*_arm64.deb | tar -x -C "$dest"
}

for pkg in $arm64_packages; do
  extract_deb "$pkg"
done

# ---------------------------------------------------------------------------
# Part 4: swap in the arm64 binaries
# ---------------------------------------------------------------------------

# A swap that silently did not land would only resurface much later as an
# unexplained runtime failure, so assert the architecture of every replacement.
# e_machine at offset 18 of the ELF header is 183 (EM_AARCH64) for arm64, 62 for
# x86-64. This is a static read, so it works on any build host.
assert_arm64() {
  local path="$1" machine

  is_elf "$path" || { echo "ERROR: $path is not an ELF binary" >&2; exit 1; }

  machine=$(od -An -tu1 -j18 -N1 "$path" | tr -d ' ')
  if [ "$machine" != "183" ]; then
    echo "ERROR: $path is not arm64 (e_machine=$machine)" >&2
    exit 1
  fi
}

is_elf() {
  head -c 4 "$1" | grep -qa 'ELF'
}

# swap_arm64_binary <package> <absolute-path-in-chroot> [group]
#
# The x86-64 build is kept as <path>.amd64, for debugging and so the swap is
# obvious to anyone inspecting the stemcell.
swap_arm64_binary() {
  local pkg="$1" path="$2" group="${3:-}"
  local src="$debs_root/$pkg$path"

  if [ ! -f "$src" ]; then
    echo "ERROR: ${pkg}:arm64 does not ship $path" >&2
    exit 1
  fi

  mv "$chroot$path" "$chroot${path}.amd64"
  install -m 0755 "$src" "$chroot$path"
  if [ -n "$group" ]; then
    run_in_chroot $chroot "chown root:$group $path"
  fi
  assert_arm64 "$chroot$path"
}

# Ubuntu 26.04's x86-64 GNU tar (1.35+dfsg-4ubuntu0.4) cannot extract anything
# under Rosetta: every file it creates fails with "Cannot open: Function not
# implemented" (ENOSYS), because tar issues a syscall Rosetta does not translate.
# Ubuntu 24.04's tar is unaffected, so this is new in 26.04. It is also the only
# tool in the base image with this problem — gzip, xz, zstd, cpio, rsync and
# coreutils are all fine.
#
# It matters at runtime, not just during the build: the BOSH agent shells out to
# tar to unpack every compiled package and release blob it downloads, so a
# stemcell with a broken tar cannot run a single deployment.
#
# dpkg has its own built-in tar reader and does not call GNU tar to unpack debs,
# so apt keeps working regardless; only direct tar invocations are affected
# (including `dpkg -x`, which does shell out to GNU tar).
swap_arm64_binary tar /usr/bin/tar

# Install arm64 private shared libraries into the arm64-specific path.
# The arm64 systemd binary's RPATH points to /usr/lib/aarch64-linux-gnu/systemd/.
mkdir -p "$chroot/usr/lib/aarch64-linux-gnu/systemd"
cp "$debs_root"/libsystemd-shared/usr/lib/aarch64-linux-gnu/systemd/libsystemd-*.so \
   "$chroot/usr/lib/aarch64-linux-gnu/systemd/"

# Replace x86_64 systemd service daemons with arm64 equivalents.
# Only daemons in /usr/lib/systemd/ are replaced; user-facing CLI tools in
# /usr/bin/ (systemctl, journalctl, etc.) are deliberately left as x86-64.
# Those tools communicate with PID1 over D-Bus and never call pidfd themselves,
# so they work correctly under Rosetta. Keeping them x86-64 also allows the
# build-time RSpec suite to execute them inside the x86-64 chroot environment.
#
# On Ubuntu 22.04+ (UsrMerge), /lib -> usr/lib, so the deb ships binaries at
# usr/lib/systemd/ rather than lib/systemd/. Symlinks there (e.g.
# systemd-udevd@ -> ../../bin/udevadm) are skipped so they keep pointing at
# their existing targets, and the package's few non-ELF helpers are left alone.
for daemon in "$debs_root"/systemd/usr/lib/systemd/*; do
  if [ -L "$daemon" ] || [ ! -f "$daemon" ] || ! is_elf "$daemon"; then
    continue
  fi

  cp "$daemon" "$chroot/usr/lib/systemd/"
  assert_arm64 "$chroot/usr/lib/systemd/$(basename "$daemon")"
done

cp "$debs_root/systemd-resolved/usr/lib/systemd/systemd-resolved" \
   "$chroot/usr/lib/systemd/systemd-resolved"
assert_arm64 "$chroot/usr/lib/systemd/systemd-resolved"

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

run_in_chroot $chroot "rm -rf $debs_dir"

# ---------------------------------------------------------------------------
# Part 5: execution self-test, where execution is possible
# ---------------------------------------------------------------------------

# The static assertions above cannot tell a working arm64 binary from one that
# will not load, so exercise the swapped tar for real — but only on a host whose
# kernel can run arm64 at all. An x86-64 CI worker has no arm64 handler and every
# exec fails with "Exec format error"; that is expected there, and the exec path
# is covered instead by the manual build on Apple Silicon
# (docs/apple-silicon-builds.md).
#
# The probe writes a marker file rather than being tested with `if
# run_in_chroot ...`: run_in_chroot's own exit status is that of its cleanup, not
# of the chroot command, so a failure is only visible through errexit — which an
# `if` condition suppresses.
probe_marker=/tmp/arm64-exec-probe
run_in_chroot $chroot "
  rm -f $probe_marker
  /lib/ld-linux-aarch64.so.1 --help >/dev/null 2>&1 && : > $probe_marker
  true
"

if [ -f "$chroot$probe_marker" ]; then
  run_in_chroot $chroot "
    set -e
    /usr/bin/tar --version >/dev/null
    rm -rf /tmp/tar-selftest
    mkdir -p /tmp/tar-selftest/src /tmp/tar-selftest/out
    echo rosetta > /tmp/tar-selftest/src/probe
    tar -czf /tmp/tar-selftest/probe.tgz -C /tmp/tar-selftest src
    tar -xzf /tmp/tar-selftest/probe.tgz -C /tmp/tar-selftest/out
    grep -q rosetta /tmp/tar-selftest/out/src/probe
    rm -rf /tmp/tar-selftest
  "
  echo "base_ubuntu_warden_rosetta: arm64 tar round-trip self-test passed."
else
  echo "base_ubuntu_warden_rosetta: SKIPPED all execution-based checks (arm64" \
       "tar --version and round-trip) — this build host cannot execute arm64" \
       "binaries at all, so not even the ELF interpreter runs. The swapped" \
       "binaries were verified statically only; run the build on Apple Silicon" \
       "to exercise them."
fi

run_in_chroot $chroot "rm -f $probe_marker"

# ---------------------------------------------------------------------------
# Part 6: binfmt_misc
# ---------------------------------------------------------------------------

# systemd-binfmt rewrites /proc/sys/fs/binfmt_misc, where Lima registers the
# Rosetta handler; letting it run risks deregistering Rosetta and leaving no
# x86-64 binary in the container executable.
run_in_chroot "$chroot" "systemctl mask systemd-binfmt.service"
