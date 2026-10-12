shared_examples_for "an os with chrony" do
  describe "(stig: V-38620 V-38621)" do
    describe file("/var/vcap/bosh/bin/sync-time") do
      it { should be_file }
      its(:content) { should match(/chronyc reload sources/) }
      its(:content) { should match(/chronyc waitsync 10/) }
    end

    describe file("/etc/chrony/chrony.conf") do
      it { should be_file }
      its(:content) { should match(/makestep 1 3/) }
    end
  end

  describe "NTP sources come only from the BOSH agent" do
    describe file("/etc/chrony/chrony.conf") do
      its(:content) { should_not match(/^\s*(pool|server|peer)\s/) }
    end

    describe file("/etc/chrony/sources.d/ubuntu-ntp-pools.sources") do
      it { should_not exist }
    end

    describe command("grep -rhE '^\\s*(pool|server|peer)\\s' /etc/chrony/conf.d /etc/chrony/sources.d") do
      its(:stdout) { should eq "" }
      # grep exits 2 on read errors (e.g. missing dir) with empty stdout
      its(:exit_status) { should be_between(0, 1) }
    end
  end
end
