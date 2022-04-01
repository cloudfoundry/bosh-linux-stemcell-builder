shared_examples_for 'a systemd-based OS image' do
  context 'systemd services' do
    describe service('runit') do
      it { should be_enabled }
    end

    describe service('rsyslog') do
      it { should_not be_enabled }
    end

    describe 'chrony service' do
      let(:chrony_service_name) do
        if (ENV['OS_NAME'] == 'rhel' && ENV['OS_VERSION'] == '8')
          # NOTE: The service is named 'chronyd' on RHEL 8.
          # SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_basic_system_settings/using-chrony-to-configure-ntp_configuring-basic-system-settings
          # SEE: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_basic_system_settings/using-chrony_configuring-basic-system-settings
          'chronyd'
        else
          'chrony'
        end
      end

      subject { service(chrony_service_name) }

      it { should be_enabled }
    end

    # describe file('/etc/systemd/system/var-log.mount.d/start_rsyslog_on_mount.conf') do
    #   # this file is an rsyslog override which make s it wait for the var/log
    #   # dir to be bind mounted before starting rsyslog
    #   it { should be_file }
    #   its(:content) { should match /^Requires=rsyslog.service/ }
    #   its(:content) { should match /^Before=rsyslog.service/ }
    # end

    describe file('/etc/systemd/system/syslog.socket.d/rsyslog_to_syslog_service.conf') do
      it { should be_file }
      its(:content) { should match /^[Socket]/ }
      its(:content) { should match /^Service=rsyslog.service/ }
    end
  end
end
