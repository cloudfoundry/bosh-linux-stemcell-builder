shared_examples_for 'an os with chrony' do
  describe '(stig: V-38620 V-38621)' do
    describe file('/var/vcap/bosh/bin/sync-time') do
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

      it { should be_file }
      it('restarts the chrony service') { expect(subject.content).to match(/^systemctl restart #{chrony_service_name}\.service$/) }
      its(:content) { should match(/^chronyc waitsync 10$/) }
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
