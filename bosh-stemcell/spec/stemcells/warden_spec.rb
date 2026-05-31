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
end
