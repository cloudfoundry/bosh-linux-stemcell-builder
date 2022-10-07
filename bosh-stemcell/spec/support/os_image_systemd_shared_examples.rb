shared_examples_for 'a systemd-based OS image' do
  context 'systemd services' do
    describe service('runit') do
      it { should be_enabled }
    end

    describe service('rsyslog') do
      it { should be_enabled }
    end

    describe service('chrony') do
      it { should be_enabled }
    end

    describe file('/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf') do
      it { should be_file }
      its(:content) { should match /^[Socket]/ }
      its(:content) { should match /^Service=rsyslog.service/ }
    end
  end
end
