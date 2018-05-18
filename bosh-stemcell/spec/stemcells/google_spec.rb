require 'spec_helper'

describe 'Google Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'rsyslog conf directory only contains files installed by rsyslog_config stage and google-compute-engine package' do
    describe command('ls -A /etc/rsyslog.d') do
      its (:stdout) { should eq(%q(50-default.conf
90-google.conf
avoid-startup-deadlock.conf
enable-kernel-logging.conf
))}
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('google') }
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
      '/usr/bin/google_instance_setup',
      '/usr/bin/google_accounts_daemon',
      '/usr/bin/google_clock_skew_daemon',
      '/usr/bin/google_metadata_script_runner'
    ]

    upstart_configs = [
      '/etc/init/google-accounts-daemon.conf',
      '/etc/init/google-clock-skew-daemon.conf',
      '/etc/init/google-instance-setup.conf',
      '/etc/init/google-shutdown-scripts.conf',
      '/etc/init/google-startup-scripts.conf'
    ]

    systemd_configs = [
      '{lib_path}/systemd/system/google-accounts-daemon.service',
      '{lib_path}/systemd/system/google-clock-skew-daemon.service',
      '{lib_path}/systemd/system/google-instance-setup.service',
      '{lib_path}/systemd/system/google-shutdown-scripts.service',
      '{lib_path}/systemd/system/google-startup-scripts.service'
    ]

    configs = usrbin

    configs += if ENV['OS_VERSION'] == 'trusty'
                 upstart_configs
               elsif ENV['OS_VERSION'] == 'xenial'
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
