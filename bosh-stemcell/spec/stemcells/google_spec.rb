require 'spec_helper'

describe 'Google Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'rsyslog conf directory only contains files installed by rsyslog_config stage and google-compute-engine package' do
    describe command('ls -A /etc/rsyslog.d') do
      it 'match expected list of rsyslog configs' do
        expected_rsyslog_confs = %w(50-default.conf
90-google.conf
)


        expect(subject.stdout.split("\n")).to match_array(expected_rsyslog_confs)
      end
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('google') }
    end
  end

  context 'growroot should be disabled by create file' do
    describe file('/etc/growroot-disabled') do
      it { should be_file }
      it { should be_owned_by('root') }
      its(:group) { should eq('root') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end

  context 'installed by system_google_packages' do
    describe 'Google agent has configuration file' do
      subject { file('/etc/default/instance_configs.cfg.template') }

      it { should be_file }
      it { should be_owned_by('root') }
      its(:group) { should eq('root') }
    end

    usrbin = [
      '/usr/bin/google_authorized_keys',
      '/usr/bin/google_guest_agent',
      '/usr/bin/google_metadata_script_runner',
      '/usr/bin/google_optimize_local_ssd',
      '/usr/bin/google_oslogin_nss_cache',
      '/usr/bin/google_set_hostname',
      '/usr/bin/google_set_multiqueue'
    ]

    upstart_configs = [
      '/etc/init/google-accounts-daemon.conf',
      '/etc/init/google-clock-skew-daemon.conf',
      '/etc/init/google-instance-setup.conf',
      '/etc/init/google-shutdown-scripts.conf',
      '/etc/init/google-startup-scripts.conf'
    ]

    systemd_configs = [
      '{lib_path}/systemd/system-preset/90-google-compute-engine-oslogin.preset',
      '{lib_path}/systemd/system/google-guest-agent.service',
      '{lib_path}/systemd/system/google-oslogin-cache.service',
      '{lib_path}/systemd/system/google-oslogin-cache.timer',
      '{lib_path}/systemd/system/google-shutdown-scripts.service',
      '{lib_path}/systemd/system/google-startup-scripts.service'
    ]

    configs = usrbin

    configs += if ENV['OS_NAME'] == 'ubuntu'
                 systemd_configs.map do |config|
                   config.gsub('{lib_path}', '/lib')
                 end
               else
                 systemd_configs.map do |config|
                   config.gsub('{lib_path}', '/usr/lib')
                 end
               end

    configs.each do |conf_file|
      describe file(conf_file) do
        it { should be_file }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end
  end
end
