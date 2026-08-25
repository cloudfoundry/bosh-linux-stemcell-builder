# The `-rosetta` stemcell variant

A stemcell built as `...,resolute-rosetta,...` inserts the
`base_ubuntu_warden_rosetta` stage into `warden_stages`. That stage makes the
**resulting stemcell** able to run as a container under Rosetta x86_64 emulation
on an arm64 kernel.

This is separate from [building on Apple Silicon](apple-silicon-builds.md),
which is about the build host. A plain `warden` stemcell built on a Mac is not a
Rosetta stemcell, and this variant would be pointless on an x86-64 host.

Only warden builds are affected; cloud infrastructure stemcells never include
the stage. Because it is gated on the variant
(`stage_collection.rb`, `operating_system.variant == "rosetta"`), the standard CI
Resolute build never exercises it — changes here have to be verified against a
deliberate `-rosetta` build.

## Why binaries get replaced

Rosetta does not translate every syscall, and its JIT compiler needs
writable+executable memory. A handful of x86-64 binaries therefore cannot run at
all. Each is replaced with the arm64 build of the same package version, which
runs natively on the arm64 kernel.

arm64 libraries install alongside the x86-64 ones under `/lib/aarch64-linux-gnu/`
via Ubuntu multiarch, and the arm64 binaries find them through their built-in
RPATH. Each replaced binary is kept as `<path>.amd64` so the swap is visible when
inspecting a stemcell.

| binary | why the x86-64 build fails |
| --- | --- |
| `tar` | Cannot extract anything (ENOSYS). See [the tar problem](apple-silicon-builds.md#ubuntu-2604s-x86-64-tar-does-not-work-under-rosetta). Needed at runtime too: the BOSH agent shells out to `tar` for every release blob. |
| systemd daemons | systemd v256+ needs `pidfd_open` / `pidfd_send_signal`. |
| `unix_chkpwd` | AppArmor denies it the Rosetta interpreter. |
| `auditd` | Cannot satisfy `Type=forking` + `MemoryDenyWriteExecute=true`. |
| `logrotate` | Killed by `MemoryDenyWriteExecute=true` (`Result=signal`). |

Only the systemd *daemons* in `/usr/lib/systemd/` are swapped. The CLI tools in
`/usr/bin` (`systemctl`, `journalctl`, `udevadm`) stay x86-64: they talk to PID 1
over D-Bus and never call pidfd themselves, and keeping them x86-64 lets the
build-time RSpec suite run them inside the x86-64 chroot.

### unix_chkpwd and AppArmor

This one is not a missing syscall. `pam_unix` forks `/usr/sbin/unix_chkpwd` to
read `/etc/shadow`, and an AppArmor profile is attached by path to
`/{,usr/}{,s}bin/unix_chkpwd`. The profile is loaded on the Lima VM, but AppArmor
is enforced by the shared kernel, so it confines that path inside containers too.
It grants the binary and `/etc/shadow` and nothing else — in particular no access
to the Rosetta interpreter, which an x86-64 build needs in order to exec:

```text
apparmor="DENIED" operation="open" profile="unix-chkpwd"
  name="mnt/lima-rosetta/rosetta" info="Failed name lookup - disconnected path"
pam_unix(sshd:account): unix_chkpwd abnormal exit: 5
```

Every PAM rule that forks the helper then fails: `su` at the auth stage, and
`bosh ssh` at the account stage, where sshd rejects the login immediately after
printing the banner even though pubkey auth succeeded.

The interpreter cannot be allow-listed. AppArmor reports it as a *disconnected*
path — note the missing leading slash above — because it lives on a mount it
cannot resolve into the host namespace, so ordinary path rules never match.
Allowing it needs `flags=(attach_disconnected)` on the profile header, which
cannot come from an `/etc/apparmor.d/local/` include and would mean every
developer editing their own VM's vendor profile.

Using the arm64 build removes the interpreter from the picture, so `/etc/pam.d`
can be left exactly as the packages and hardening stages produce it.

## Before changing anything PAM-related

`unix_chkpwd` has bitten this repo more than once, in ways that are easy to
misdiagnose. Worth reading before touching `/etc/pam.d`, `/etc/shadow` or the
helper's permissions.

**Do not route around `unix_chkpwd` in PAM.** Replacing an account rule with
`pam_permit`, or adding `account sufficient pam_rootok.so`, resolves the symptom
by skipping the entire account stack — including the `pam_faillock` rule this repo
adds in `password_policies/assets/ubuntu/common-account.patch`, and account-expiry
enforcement. On `/etc/pam.d/su` the equivalent shortcut on the *auth* stack also
stops passwords being verified at all, letting any wheel member become root
without one.

**`su: Authentication failure` does not mean the auth stack failed.** Ubuntu's
`/bin/su` is util-linux, not shadow, and it prints `pam_strerror()` for a failure
of *either* `pam_authenticate` or `pam_acct_mgmt`. The account stack is the more
common culprit, because that is where `pam_unix` forks `unix_chkpwd`.

**`/etc/shadow` is mode `0400`, not the `0000` STIG V-38504 asks for.** In PAM
1.7.0, which Resolute ships, `unix_chkpwd` links `libcap-ng` and drops
`CAP_DAC_OVERRIDE` before opening `/etc/shadow`. At `0000 root:root` nothing can
read it — not even root, and not with full `CapEff` — so `unix_chkpwd … chkexpiry`
exits 9 and every `su` fails. `0400` still denies group and other, which is the
intent of the control. PAM 1.5.3 (Noble) and 1.4.0 (Jammy) are unaffected. See
`stemcell_builder/stages/base_file_permission/apply.sh`.

**Restoring the helper's setgid bit is a red herring for that one.**
`restrict_binary_setuid` in `stemcell_builder/lib/prelude_bosh.bash` does strip it,
but `/etc/shadow` is `root:root`, so `setgid shadow` grants nothing; re-adding it
leaves `su` broken. It is also why this stage installs the arm64 helper `0755`
rather than the `2755` the deb ships — see the table above.

**Do not reproduce shadow-permission problems on Apple Silicon.** On aarch64,
`unix_chkpwd … chkexpiry` succeeds against a `0000` shadow and `su` works, so an
aarch64 repro of that bug falsely passes. It only manifests on x86_64. (The
AppArmor problem above is the opposite: it needs Rosetta to reproduce.)

**Do not reorder `pam_wheel` in `/etc/pam.d/su`.** `restrict_su_command` appends
`auth required pam_wheel.so use_uid` for CIS-9.5, which lands *after* the stock
file's `auth sufficient pam_rootok.so`. That ordering is what lets root bypass the
wheel check; moving the appended line up would force root through it.

**Test against a fresh container.** Hand-edited PAM files in a long-lived debug
container will make broken configurations look like working ones:

```shell
docker run --rm --entrypoint bash bosh.io/stemcells:img-<id> -c '…'
```

## systemd-binfmt is masked

`systemd-binfmt` rewrites `/proc/sys/fs/binfmt_misc`, which is where Lima
registers the Rosetta handler. Letting it run risks deregistering Rosetta and
leaving no x86-64 binary in the container executable. This is unrelated to the
architecture of the `systemd-binfmt` binary itself.

## Service hardening

The stage relaxes no systemd hardening. `MemoryDenyWriteExecute`,
`SystemCallFilter`, `LockPersonality` and `NoNewPrivileges` are left as the
vendor units ship them.

Relaxing them is only ever correct for a service whose binary is still x86-64,
because the reason to do so is Rosetta's need for W+X memory. Before adding such
an override, check the binary's architecture:

```shell
od -An -tu1 -j18 -N1 /usr/sbin/logrotate   # 183 = arm64, 62 = x86-64
```

An arm64 binary does not need it, and adding one weakens the stemcell for no
benefit. `bosh-stemcell/spec/stemcells/rosetta_spec.rb` asserts these overrides
are absent.

## Units that cannot work in a container

Handled in `base_warden`, not this stage, because they apply to every warden
stemcell regardless of architecture. Both are skipped with
`ConditionVirtualization=!container` rather than masked, so the stemcell still
behaves correctly if booted on a VM, and the journal records why:

- **`audit-rules.service`** — the kernel audit subsystem is not namespaced.
  `audit_netlink_ok()` in `kernel/audit.c` rejects `AUDIT_ADD_RULE`,
  `AUDIT_DEL_RULE` and `AUDIT_LIST_RULES` unless the caller is in the initial PID
  namespace, so `auditctl` gets `-EPERM` and the unit fails on the `-D` at line 2
  of `/etc/audit/audit.rules`. Being privileged and holding
  `cap_audit_control` does not help. `/etc/audit/audit.rules` is left intact for
  the STIG/CIS content checks, and `auditd` still starts because it only
  `Wants=` this unit. Do not expect audit records from inside a container.
- **`netplan-configure.service`** — these images ship no `/etc/netplan`, so it
  generates nothing, and its `ExecStartPost` runs `udevadm control --reload`
  against the `systemd-udevd` that `base_warden` masks.
