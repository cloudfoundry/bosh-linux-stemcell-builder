shared_examples_for 'a systemd-based OS image' do

  context 'installed by rsyslog_config' do
    # systemd startup may not be needed: see https://www.pivotaltracker.com/story/show/90100234
  end

  context 'systemd services' do
    describe service('runit') do
      it { should be_enabled }
    end

    describe service('rsyslog') do
      it { should_not be_enabled }
    end

    describe file('/etc/systemd/system/var-log.mount.d/start_rsyslog_on_mount.conf') do
      # this file is an rsyslog override which make s it wait for the var/log
      # dir to be bind mounted before starting rsyslog
      it { should be_file }
      its(:content) { should match /^Requires=rsyslog.service/ }
      its(:content) { should match /^Before=rsyslog.service/ }
    end

    describe file('/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf') do
      it { should be_file }
      its(:content) { should match /^[Socket]/ }
      its(:content) { should match /^Service=rsyslog.service/ }
    end
  end
end
