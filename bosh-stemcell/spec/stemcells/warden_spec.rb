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
end
