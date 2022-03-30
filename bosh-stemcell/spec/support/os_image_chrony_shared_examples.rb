shared_examples_for 'an os with chrony' do
  describe '(stig: V-38620 V-38621)' do
    describe file('/var/vcap/bosh/bin/sync-time') do
      it { should be_file }
      its(:content) { should match(/systemctl restart chrony\.service/) }
      its(:content) { should match(/chronyc waitsync 10/) }
    end

    describe 'chrony.conf file' do
      let(:chrony_config_path) do
        if ENV['OS_NAME'] == 'ubuntu'
          '/etc/chrony/chrony.conf'
        else
          '/etc/chrony.conf'
        end
      end

      subject { file(chrony_config_path) }

      it { should be_file }
      its(:content) { should match(/^makestep 1(\.0)? 3$/) }
    end
  end
end
