require "spec_helper"

describe "Warden Stemcell", stemcell_image: true do
  it_behaves_like "udf module is disabled"

  context "installed by system_parameters" do
    describe file("/var/vcap/bosh/etc/infrastructure") do
      its(:content) { should include("warden") }
    end
  end

  context "auditd config" do
    describe file("/etc/audit/auditd.conf") do
      its(:content) { should include("local_events = no") }
    end
  end

  context "systemd config" do
    describe file("/etc/systemd/system.conf") do
      its(:content) { should include("DefaultStartLimitBurst=500") }
    end
  end

  context "installed by base_warden" do
    describe file("/etc/sysctl.d/20-disable-apparmor-restrict.conf") do
      it { should be_file }
      its(:mode) { should eq(0o644) }
      its(:content) { should match(/^kernel\.apparmor_restrict_unprivileged_userns = 0$/) }
      its(:content) { should match(/^kernel\.apparmor_restrict_unprivileged_unconfined = 0$/) }
    end
  end

  context "units that cannot work in a container are skipped, not failed" do
    # audit-rules needs the initial PID namespace; netplan-configure has no
    # /etc/netplan and its ExecStartPost needs the masked systemd-udevd.
    describe file("/etc/systemd/system/audit-rules.service.d/warden-skip-in-container.conf") do
      it { should be_file }
      its(:content) { should include("ConditionVirtualization=!container") }
    end

    describe file("/etc/systemd/system/netplan-configure.service.d/warden-skip-in-container.conf") do
      it { should be_file }
      its(:content) { should include("ConditionVirtualization=!container") }
    end

    # STIG/CIS checks read this file's content, so skipping the unit must not
    # remove it.
    describe file("/etc/audit/audit.rules") do
      it { should be_file }
    end
  end

  context "Rosetta x86_64 emulation compatibility for Apple Silicon" do
    # These systemd drop-in overrides disable security features that conflict
    # with Rosetta's JIT compilation on Apple Silicon Macs

    rosetta_services = %w[
      systemd-journald
      systemd-resolved
      systemd-networkd
      systemd-logind
      systemd-timesyncd
      auditd
      logrotate
    ]

    rosetta_services.each do |service|
      describe file("/etc/systemd/system/#{service}.service.d/rosetta-compat.conf") do
        it { should be_file }
        its(:content) { should include("MemoryDenyWriteExecute=no") }
        its(:content) { should include("LockPersonality=no") }
        its(:content) { should include("NoNewPrivileges=no") }
      end
    end

    warden_masked_units = %w[
      systemd-udevd.service
      chrony.service
      systemd-binfmt.service
    ]

    warden_masked_units.each do |unit|
      describe file("/etc/systemd/system/#{unit}") do
        it { should be_linked_to File::NULL }
      end
    end
  end
end
