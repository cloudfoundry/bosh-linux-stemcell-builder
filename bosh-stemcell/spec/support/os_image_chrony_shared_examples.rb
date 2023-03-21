shared_examples_for 'an os with chrony' do
  describe '(stig: V-38620 V-38621)' do
    describe file('/var/vcap/bosh/bin/sync-time') do
      it { should be_file }
      its(:content) { should match(/chronyc reload sources/) }
      its(:content) { should match(/chronyc waitsync 10/) }
    end

    describe file('/etc/chrony/chrony.conf') do
      it { should be_file }
      its(:content) { should match(/makestep 1 3/) }
    end
  end
end
