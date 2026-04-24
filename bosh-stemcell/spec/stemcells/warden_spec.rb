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

  context "runit removed (Resolute Raccoon: no chpst)" do
    # Per the Resolute RFC #1498 the runit package is removed from the
    # stemcell. Releases must migrate off chpst (BPM / su / runuser / setpriv).
    #
    # This negative-assertion test should be removed in the next stemcell line.
    describe file("/usr/bin/chpst") do
      it { should_not be_file }
    end

    describe file("/usr/bin/runsv") do
      it { should_not be_file }
    end

    describe file("/usr/sbin/runit") do
      it { should_not be_file }
    end

    describe package("runit") do
      it { should_not be_installed }
    end
  end

  context "/tmp tmpfs handled (systemd 259)" do
    # systemd 259 mounts /tmp as a world-writable tmpfs via the static tmp.mount
    # unit. Mask it so /tmp stays a hardened, disk-backed directory.
    describe file("/etc/systemd/system/tmp.mount") do
      it { should be_linked_to File::NULL }
    end
  end
end
