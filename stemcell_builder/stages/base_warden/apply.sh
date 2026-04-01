#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Explicit make the mount point for bind-mount
# Otherwise using none ubuntu host will fail creating vm
mkdir -p $chroot/warden-cpi-dev

# Auditd cannot capture events within a container
sed -i 's/^local_events = yes$/local_events = no/g' $chroot/etc/audit/auditd.conf

# As containers have less to startup, some services are restarted very quickly and can hit the systemd
# restart limit of 5 restarts in 5 seconds
sed -i 's/^#DefaultStartLimitBurst=5$/DefaultStartLimitBurst=500/g' $chroot/etc/systemd/system.conf

# Override the upstream AppArmor sysctl restrictions that ship in
# /usr/lib/sysctl.d/10-apparmor.conf on Ubuntu 26.04+.  When systemd-sysctl
# runs inside a privileged container it writes to the *host* /proc/sys,
# resetting kernel.apparmor_restrict_unprivileged_userns to 1 and breaking
# any host process that relies on unprivileged user namespaces.
if [ -f "$chroot/usr/lib/sysctl.d/10-apparmor.conf" ]; then
  cat > "$chroot/etc/sysctl.d/20-disable-apparmor-restrict.conf" <<SYSCTL
kernel.apparmor_restrict_unprivileged_userns = 0
kernel.apparmor_restrict_unprivileged_unconfined = 0
SYSCTL
  chmod 0644 "$chroot/etc/sysctl.d/20-disable-apparmor-restrict.conf"
fi

cat > $chroot/var/vcap/bosh/bin/restart_networking <<EOF
#!/bin/bash

echo "skip network restart: network is already preconfigured"
EOF
chmod +x $chroot/var/vcap/bosh/bin/restart_networking

# Configure go agent specifically for warden
cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "UseDefaultTmpDir": true,
      "UsePreformattedPersistentDisk": true,
      "BindMountPersistentDisk": true,
      "SkipDiskSetup": true,
      "ServiceManager": "systemd"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "File",
          "SettingsPath": "/var/vcap/bosh/warden-cpi-agent-env.json"
        }
      ]
    }
  }
}
JSON

# Rosetta x86_64 emulation compatibility for Apple Silicon Macs
#
# When running warden stemcells under Rosetta emulation on Apple Silicon,
# several systemd services fail because their security hardening features
# (MemoryDenyWriteExecute, SystemCallFilter, etc.) conflict with Rosetta's
# JIT compilation which requires writable+executable memory.
#
# We create systemd drop-in overrides to disable these security features.
# This is acceptable for warden stemcells since they run in containerized
# environments where the host provides security isolation.

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

#todo: add udevd test

for service in "${rosetta_services[@]}"; do
  mkdir -p "$chroot/etc/systemd/system/${service}.service.d"
  cp "$assets_dir/rosetta-compat.conf" "$chroot/etc/systemd/system/${service}.service.d/rosetta-compat.conf"
done

# Mask systemd-binfmt.service which fails under Rosetta emulation
run_in_chroot "$chroot" "systemctl mask systemd-binfmt.service"

# auditd: systemd can return ENOSYS when creating pidfd/cgroup references from PIDFile under Docker/Colima
# ("Failed to create reference to PID ... auditd.pid"). Foreground auditd avoids forking + PIDFile lifecycle quirks.
mkdir -p "$chroot/etc/systemd/system/auditd.service.d"
cat > "$chroot/etc/systemd/system/auditd.service.d/warden-auditd-foreground.conf" <<'UNIT'
[Service]
Type=simple
PIDFile=
ExecStart=
ExecStart=/usr/sbin/auditd -n
UNIT

# TODO: maybe this should go up out of warden?
run_in_chroot "$chroot" "systemctl mask nvmf-autoconnect.service"


# Ubuntu enables OpenSSH via ssh.socket (socket activation). systemd's listener stub fork can fail with
# ENOSYS ("Function not implemented") under Docker/Colima and similar, especially with Rosetta x86_64
# emulation — see journalctl -u ssh.socket. Use the traditional ssh.service so sshd binds port 22 itself.
mkdir -p "$chroot/etc/systemd/system/ssh.service.d"
cat > "$chroot/etc/systemd/system/ssh.service.d/warden-no-socket-activation.conf" <<'UNIT'
[Unit]
# When ssh.socket is masked, sshd must start via ssh.service; drop RefuseManualStart from the vendor unit.
RefuseManualStart=no
UNIT
run_in_chroot "$chroot" "systemctl mask ssh.socket"
run_in_chroot "$chroot" "systemctl enable ssh.service"

run_in_chroot "$chroot" "systemctl mask systemd-udevd.service"

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
# This override is safe for warden containers: the host provides isolation,
# and the container root user is already fully privileged.
cat > "$chroot/etc/pam.d/su" <<'PAMEOF'
# PAM configuration for su - warden stemcell override.
# AppArmor blocks unix-chkpwd under Lima/Rosetta causing su to fail even for root.
# pam_rootok handles legitimate root → any-user su; pam_permit covers the rest.
auth       sufficient pam_rootok.so
auth       required   pam_permit.so
account    required   pam_permit.so
session    required   pam_env.so readenv=1
session    required   pam_limits.so
PAMEOF
chmod 0644 "$chroot/etc/pam.d/su"
