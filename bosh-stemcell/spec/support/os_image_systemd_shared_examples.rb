shared_examples_for 'a systemd-based OS image' do
  context 'systemd services' do
    describe service('monit') do
      it { should be_enabled }
    end

    describe service('rsyslog') do
      it { should be_enabled }
    end

    describe service('chrony') do
      it { should be_enabled }
    end

    describe file('/etc/systemd/system/chronyd.service.d/prevent_mount_locking.conf') do
      it { should be_file }
      its(:content) { should match /^InaccessiblePaths=-\/var\/vcap\/store/ }
    end

    describe file('/etc/systemd/journald.conf.d/00-override.conf') do
      it { should be_file }
      its(:content) { should match /^Storage=volatile/ }
    end

    describe file('/etc/systemd/system/rsyslog.service.d/00-override.conf') do
      it { should be_file }
      its(:content) { should match /^ExecStartPre=\/usr\/local\/bin\/wait_for_var_log_to_be_mounted/ }
    end
  end
end
