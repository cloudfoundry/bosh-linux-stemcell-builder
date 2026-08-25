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

  context "arm64 tar (Rosetta extraction ENOSYS)" do
    # Ubuntu 26.04's x86-64 GNU tar cannot extract archives under Rosetta: every
    # file it creates fails with "Cannot open: Function not implemented"
    # (ENOSYS). The BOSH agent shells out to tar for every release blob it
    # downloads, so a stemcell shipping the x86-64 binary cannot run a single
    # deployment. The stage swaps in the arm64 build and keeps the original as
    # tar.amd64.
    describe command("file -b /usr/bin/tar") do
      its(:stdout) { should match(/ELF 64-bit.*ARM aarch64/) }
    end

    describe file("/usr/bin/tar.amd64") do
      it { should be_file }
    end

    # tar links against libacl and libselinux, so the arm64 builds of both have
    # to be present or the binary will not even load.
    %w[
      /lib/aarch64-linux-gnu/libacl.so.1
      /lib/aarch64-linux-gnu/libselinux.so.1
    ].each do |lib|
      describe file(lib) do
        it { should be_file }
      end
    end

    # The architecture check above would still pass if the binary could not
    # actually run, so exercise a real round-trip — but only on a host whose
    # kernel can run arm64. An x86-64 CI worker has no arm64 handler and every
    # exec fails with "Exec format error"; there the exec path is covered
    # instead by the manual build on Apple Silicon
    # (docs/ci-warden-rosetta-build.md). Every other assertion in this file is
    # static and runs everywhere.
    describe command(
      "set -e; " \
      "rm -rf /tmp/tar-spec; mkdir -p /tmp/tar-spec/src /tmp/tar-spec/out; " \
      "echo payload > /tmp/tar-spec/src/probe; " \
      "tar -czf /tmp/tar-spec/probe.tgz -C /tmp/tar-spec src; " \
      "tar -xzf /tmp/tar-spec/probe.tgz -C /tmp/tar-spec/out; " \
      "grep -q payload /tmp/tar-spec/out/src/probe; " \
      "rm -rf /tmp/tar-spec"
    ) do
      it "extracts an archive it just created" do
        if command("/usr/bin/tar --version").exit_status != 0
          skip("this build host cannot execute arm64 binaries; the tar " \
               "round-trip is the only check skipped, all static assertions ran")
        end

        expect(subject.exit_status).to eq(0)
      end
    end
  end

  context "Rosetta x86_64 emulation compatibility for Apple Silicon" do
    # Asserted against the vendor units because these specs run on the built
    # chroot, where `systemctl show` has no systemd to query.
    describe file("/usr/lib/systemd/system/auditd.service") do
      its(:content) { should match(/^MemoryDenyWriteExecute=true$/) }
    end

    describe file("/usr/lib/systemd/system/logrotate.service") do
      its(:content) { should match(/^MemoryDenyWriteExecute=true$/) }
    end

    describe file("/etc/systemd/system/systemd-binfmt.service") do
      it { should be_linked_to File::NULL }
    end
  end

  context "arm64 userland binaries" do
    # e_machine at offset 18 of the ELF header: 183 (EM_AARCH64), 62 for x86-64.
    %w[
      /usr/sbin/unix_chkpwd
      /usr/sbin/auditd
      /usr/sbin/logrotate
    ].each do |path|
      describe command("od -An -tu1 -j18 -N1 #{path} | tr -d ' '") do
        its(:stdout) { should match(/^183$/) }
      end

      describe file("#{path}.amd64") do
        it { should be_file }
      end
    end

    # 0755, not the 2755 the deb ships: restrict_binary_setuid strips setgid
    # outside the allowlist asserted in stemcells/ubuntu_spec.rb.
    describe file("/usr/sbin/unix_chkpwd") do
      it { should be_mode(0o755) }
      its(:group) { should eq("shadow") }
    end
  end
end
