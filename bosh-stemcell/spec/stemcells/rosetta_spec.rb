require "spec_helper"

describe "Rosetta Warden Stemcell", stemcell_image: true do
  context "arm64 systemd binaries (Rosetta pidfd fix)" do
    # On Apple Silicon (arm64 kernel + Rosetta x86_64 emulation), systemd v256+
    # calls pidfd_open and pidfd_send_signal which Rosetta does not translate for
    # x86_64 processes, causing ENOSYS. These assertions verify that all key
    # systemd binaries have been replaced with arm64 ELF equivalents so they run
    # natively on the arm64 kernel without Rosetta translation.

    # Only service daemons are replaced with arm64; user-facing CLI tools in
    # /usr/bin/ (systemctl, journalctl, etc.) remain x86-64 because they
    # communicate with PID1 over D-Bus and never call pidfd themselves.
    %w[
      /usr/lib/systemd/systemd
      /usr/lib/systemd/systemd-executor
      /usr/lib/systemd/systemd-journald
      /usr/lib/systemd/systemd-logind
      /usr/lib/systemd/systemd-networkd
      /usr/lib/systemd/systemd-resolved
      /usr/lib/systemd/systemd-shutdown
    ].each do |bin|
      describe command("file #{bin}") do
        its(:stdout) { should match(/ELF 64-bit.*ARM aarch64/) }
      end
    end

    # arm64 runtime libraries land in /lib/aarch64-linux-gnu/ via Ubuntu multiarch.
    # On Ubuntu 22.04+ (UsrMerge), /lib is a symlink to usr/lib; the real file is
    # at /lib/aarch64-linux-gnu/libc.so.6 (resolves via the UsrMerge symlink).
    describe file("/lib/aarch64-linux-gnu/libc.so.6") do
      it { should be_file }
    end

    # The arm64 ELF interpreter is at the multiarch path; /lib/ld-linux-aarch64.so.1
    # is a symlink to it but ShelloutTypes::File cannot check symlink targets reliably.
    describe file("/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1") do
      it { should be_file }
    end

    describe file("/usr/lib/aarch64-linux-gnu/systemd/libsystemd-shared-259.so") do
      it { should be_file }
    end
  end

  context "Rosetta x86_64 emulation compatibility for Apple Silicon" do
    # These systemd drop-in overrides disable security features that conflict
    # with Rosetta's JIT compilation on Apple Silicon Macs.

    rosetta_services = %w[
      systemd-journald
      systemd-resolved
      systemd-networkd
      systemd-logind
      systemd-timesyncd
      auditd
    ]

    rosetta_services.each do |service|
      describe file("/etc/systemd/system/#{service}.service.d/rosetta-compat.conf") do
        it { should be_file }
        its(:content) { should include("MemoryDenyWriteExecute=no") }
        its(:content) { should include("LockPersonality=no") }
        its(:content) { should include("NoNewPrivileges=no") }
      end
    end

    describe file("/etc/systemd/system/systemd-binfmt.service") do
      it { should be_linked_to File::NULL }
    end
  end

  context "SSH without socket activation (Rosetta/Colima ENOSYS)" do
    describe file("/etc/systemd/system/ssh.socket") do
      it { should be_linked_to File::NULL }
    end

    describe file("/etc/systemd/system/ssh.service.d/warden-no-socket-activation.conf") do
      it { should be_file }
      its(:content) { should include("RefuseManualStart=no") }
    end
  end

  context "auditd foreground (Rosetta/Colima Docker pidfd ENOSYS)" do
    # Under Docker/Colima with Rosetta emulation, systemd cannot create pidfd
    # references or cgroup entries for processes started with Type=forking + PIDFile.
    # Running auditd with -n (no-fork / foreground) avoids the fork-and-PIDFile
    # lifecycle entirely, so systemd tracks the process directly without pidfd.
    describe file("/etc/systemd/system/auditd.service.d/warden-auditd-foreground.conf") do
      it { should be_file }
      its(:content) { should include("Type=simple") }
      its(:content) { should include("ExecStart=/usr/sbin/auditd -n") }
    end
  end

  context "restrict access to the su command CIS-9.5 (Rosetta PAM override)" do
    # The Rosetta stemcell replaces /etc/pam.d/su with a minimal config that
    # avoids unix-chkpwd (which AppArmor blocks under Lima/Rosetta, causing every
    # su invocation to fail with "Authentication failure" even for root).
    # pam_wheel.so use_uid is kept in the replacement config so that the CIS-9.5
    # requirement — only wheel-group members may use su — is still enforced.
    # This test verifies that the override did not inadvertently remove the wheel check.
    describe command('grep "^\s*auth\s*required\s*pam_wheel.so\s*use_uid" /etc/pam.d/su') do
      it("exits 0") { expect(subject.exit_status).to eq(0) }
    end
  end
end
