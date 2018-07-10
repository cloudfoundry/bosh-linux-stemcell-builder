shared_examples_for 'an os with chrony' do
  describe '(stig: V-38620 V-38621)' do
    describe file('/var/vcap/bosh/bin/sync-time') do
      it { should be_file }
      its(:content) { should match(/systemctl restart chrony\.service/) }
      its(:content) { should match(/chronyc waitsync 10/) }
    end

    describe file('/etc/chrony/chrony.conf') do
      it { should be_file }
      its(:content) { should match(/makestep 3 1/) }
    end
  end
end
