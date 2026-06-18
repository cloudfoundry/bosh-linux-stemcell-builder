#!/usr/bin/env bash

# Rosetta-specific warden stemcell stage.
#
# Applies two categories of fix for warden containers running under
# Lima/Rosetta x86_64 emulation on Apple Silicon (arm64 kernel):
#
# 1. ARM64 SYSTEMD BINARIES
#    On Apple Silicon (arm64 kernel + Rosetta x86_64 emulation), systemd v256+
#    requires pidfd_open and pidfd_send_signal syscalls that Rosetta does not
#    translate for x86_64 processes, causing ENOSYS. Replacing the systemd ELF
#    binaries with arm64 equivalents causes them to run natively on the arm64
#    kernel, giving full pidfd support.
#
#    arm64 shared libraries land in /lib/aarch64-linux-gnu/ via Ubuntu multiarch
#    and coexist with the x86_64 libraries already in /lib/x86_64-linux-gnu/.
#    The arm64 ELF binaries reference those library paths via their built-in RPATH.
#
# 2. ROSETTA COMPATIBILITY OVERRIDES
#    Rosetta's JIT compiler requires writable+executable (W+X) memory.  Several
#    systemd services have security hardening that blocks W+X (MemoryDenyWriteExecute,
#    SystemCallFilter, etc.), causing them to crash on startup.  We apply drop-in
#    overrides to disable these restrictions.  AppArmor also blocks unix-chkpwd
#    from accessing the Rosetta runtime path, causing su to fail; we replace
#    /etc/pam.d/su with a config that avoids unix-chkpwd entirely.
#
# This stage is only inserted into warden_stages when the OS variant is
# "rosetta" (i.e. rake ... ubuntu,resolute-rosetta,...). Standard warden
# and all cloud infrastructure stemcell builds are unaffected.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# ---------------------------------------------------------------------------
# Part 1: arm64 systemd binaries
# ---------------------------------------------------------------------------

# Enable arm64 as a foreign architecture so apt can resolve arm64 packages.
run_in_chroot $chroot "dpkg --add-architecture arm64"
run_in_chroot $chroot "apt-get update"

# Install arm64 runtime libraries that systemd depends on.
# These install into /lib/aarch64-linux-gnu/ and /usr/lib/aarch64-linux-gnu/,
# coexisting safely with the existing amd64 libraries.
# libc6:arm64 also places /lib/ld-linux-aarch64.so.1 (the arm64 ELF interpreter).
arm64_libs="libc6:arm64 \
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
  libgpg-error0:arm64"

run_in_chroot $chroot "apt-get install --no-install-recommends --assume-yes $arm64_libs"

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
# Part 2: Rosetta compatibility overrides
# ---------------------------------------------------------------------------

# Apply systemd drop-ins that disable security hardening features conflicting
# with Rosetta's JIT compilation (which requires writable+executable memory).
rosetta_services=(
  systemd-journald
  systemd-resolved
  systemd-networkd
  systemd-logind
  systemd-timesyncd
  systemd-udevd
  logrotate
  auditd
)

for service in "${rosetta_services[@]}"; do
  mkdir -p "$chroot/etc/systemd/system/${service}.service.d"
  cp "$assets_dir/rosetta-compat.conf" "$chroot/etc/systemd/system/${service}.service.d/rosetta-compat.conf"
done

# Mask systemd-binfmt.service which fails under Rosetta emulation.
run_in_chroot "$chroot" "systemctl mask systemd-binfmt.service"

# auditd: systemd can return ENOSYS when creating pidfd/cgroup references from
# PIDFile under Docker/Colima. Foreground auditd avoids forking + PIDFile quirks.
mkdir -p "$chroot/etc/systemd/system/auditd.service.d"
cat > "$chroot/etc/systemd/system/auditd.service.d/warden-auditd-foreground.conf" <<'UNIT'
[Service]
Type=simple
PIDFile=
ExecStart=
ExecStart=/usr/sbin/auditd -n
UNIT

# Ubuntu enables OpenSSH via ssh.socket (socket activation). systemd's listener
# stub fork can fail with ENOSYS under Docker/Colima with Rosetta x86_64
# emulation. Use the traditional ssh.service so sshd binds port 22 itself.
mkdir -p "$chroot/etc/systemd/system/ssh.service.d"
cat > "$chroot/etc/systemd/system/ssh.service.d/warden-no-socket-activation.conf" <<'UNIT'
[Unit]
# When ssh.socket is masked, sshd must start via ssh.service; drop RefuseManualStart from the vendor unit.
RefuseManualStart=no
UNIT
run_in_chroot "$chroot" "systemctl mask ssh.socket"
run_in_chroot "$chroot" "systemctl enable ssh.service"

# Fix `su` PAM authentication failures under Colima/Lima (Apple Silicon).
#
# Under Lima's Rosetta x86_64 emulation, AppArmor blocks unix-chkpwd
# (an x86_64 binary) from accessing the Rosetta runtime path
# /mnt/lima-rosetta/rosetta, causing every `su` invocation to fail with
# "Authentication failure" — even for root.  The standard PAM config in
# /etc/pam.d/su includes common-auth, which chains pam_faillock → pam_unix,
# and pam_unix forks unix-chkpwd to verify passwords.  That fork triggers
# the AppArmor denial.
#
# pam_rootok.so already handles "root switching to any user" correctly on
# its own, but because pam_unix / pam_faillock come after it in common-auth
# they still run (pam_rootok is "sufficient" only when it *succeeds* at the
# auth step level, not at the include level).  Using pam_permit for the
# remaining auth/account rules means root can always su without unix-chkpwd.
#
# pam_wheel.so use_uid is retained (CIS-9.5): it only checks group membership
# and never forks unix-chkpwd, so it is safe under Rosetta/AppArmor.
# pam_rootok is "sufficient", so root bypasses the wheel check entirely;
# non-root users must be in the wheel group (vcap is added by restrict_su_command).
#
# This override is safe for warden containers: the host provides isolation,
# and the container root user is already fully privileged.
cat > "$chroot/etc/pam.d/su" <<'PAMEOF'
# PAM configuration for su - warden Rosetta stemcell override.
# AppArmor blocks unix-chkpwd under Lima/Rosetta causing su to fail even for root.
# pam_rootok handles legitimate root → any-user su; pam_permit covers the rest.
# pam_wheel.so use_uid is kept for CIS-9.5 compliance (does not invoke unix-chkpwd).
auth       sufficient pam_rootok.so
auth       required   pam_wheel.so use_uid
auth       required   pam_permit.so
account    required   pam_permit.so
session    required   pam_env.so readenv=1
session    required   pam_limits.so
PAMEOF
chmod 0644 "$chroot/etc/pam.d/su"
