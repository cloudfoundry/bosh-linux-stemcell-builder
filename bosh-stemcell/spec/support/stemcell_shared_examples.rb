require 'rspec'

shared_examples_for 'All Stemcells' do

  context 'building a new stemcell' do
    describe file '/var/vcap/bosh/etc/stemcell_version' do
      let(:expected_version) { ENV['CANDIDATE_BUILD_NUMBER'] || '0000' }

      it { should be_file }
      its(:content) { should eq expected_version }
    end

    describe file '/var/vcap/bosh/etc/stemcell_git_sha1' do
      it { should be_file }
      its(:content) { should match '^[0-9a-f]{40}\+?$' }
    end

    describe command('ls -l /etc/ssh/*_key*') do
      its(:stderr) { should match /No such file or directory/ }
    end
  end

  context 'ipv6 is disabled in the kernel', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vsphere: true,
  } do
    describe file('/boot/grub/grub.cfg') do
      its(:content) { should match(/^\s+(kernel|linux)\s.*\sipv6\.disable=1\s.*$/) }
    end
    describe file('/boot/efi/EFI/grub/grub.cfg') do
      its(:content) { should match(/^\s+(kernel|linux)\s.*\sipv6\.disable=1\s.*$/) }
    end
  end

  context 'ipv6 is disabled in the kernel on EFI', {
    exclude_on_softlayer: true,
    exclude_on_cloudstack: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_azure: true,
  } do
    describe file('/boot/efi/EFI/grub/grub.cfg') do
      its(:content) { should match(/^\s+(kernel|linux)\s.*\sipv6\.disable=1\s.*$/) }
    end
  end

  context 'disable remote host login (stig: V-38491)' do
    describe command('find /home -name .rhosts') do
      its (:stdout) { should eq('') }
    end

    describe file('/etc/hosts.equiv') do
      it { should_not be_file }
    end
  end

  context 'system library files' do
    describe file('/lib') do
      it('should be owned by root user (stig: V-38466)') { should be_owned_by('root') }
    end

    describe file('/lib64') do
      it('should be owned by root user (stig: V-38466)') { should be_owned_by('root') }
    end

    describe file('/usr/lib') do
      it('should be owned by root user (stig: V-38466)') { should be_owned_by('root') }
    end

    describe command('if [ -e /usr/lib64 ]; then stat -c "%U" /usr/lib64 ; else echo "root" ; fi') do
      its (:stdout) { should eq("root\n") }
    end
  end

  describe file('/var/vcap/micro_bosh/data/cache') do
    it('should still be created') { should be_directory }
  end

  context 'Library files must have mode 0755 or less permissive (stig: V-38465)' do
    describe command("find -L /lib /lib64 /usr/lib $( [ ! -e /usr/lib64 ] || echo '/usr/lib64' ) -perm /022 -type f") do
      its (:stdout) { should eq('') }
    end
  end

  context 'System command files must have mode 0755 or less permissive (stig: V-38469)' do
    describe command('find -L /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin -perm /022 -type f') do
      its (:stdout) { should eq('') }
    end
  end

  context 'all system command files must be owned by root (stig: V-38472)' do
    describe command('find -L /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin ! -user root') do
      its (:stdout) { should eq('') }
    end
  end

  context 'There must be no .netrc files on the system (stig: V-38619)' do
    describe command('sudo find /root /home /var/vcap -xdev -name .netrc') do
      # its (:stdout) { should eq('') }
      it 'does not include .netrc' do
        results = subject.stdout.split("\n").reject { |str| str.match(/^Last login/) }
        expect(results).to eq []
      end
    end
  end

  context 'rsyslog conf directory only contains the builder-specified config files', exclude_on_google: true do
    describe command('ls -A /etc/rsyslog.d') do
      its (:stdout) do
        should eq(<<~FILELIST)
          50-default.conf
          90-bosh-agent.conf
        FILELIST
      end
    end
  end

  describe file('/var/vcap/bosh/bin/restart_networking') do
    it { should be_file }
    it { should be_executable }
    it { should be_owned_by('root') }
    its(:group) { should eq('root') }

    context 'restarts systemd-networkd on non-warden images', {
      exclude_on_warden: true,
    } do
      its(:content) { should eql(<<HERE) }
#!/bin/bash
systemctl restart systemd-networkd
HERE
    end

    context 'does nothing on warden', {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_cloudstack: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      its(:content) { should eql(<<HERE) }
#!/bin/bash

echo "skip network restart: network is already preconfigured"
HERE
    end
  end

  describe 'logrotate' do
    describe command('grep ionice /usr/bin/logrotate-cron') do
      its(:stdout) { should match(%r{^\s*nice -n 19 ionice -c3 /usr/sbin/logrotate\b}) }
    end

    describe 'should rotate every 15 minutes' do
      describe file('/etc/cron.d/logrotate') do
        it { should be_mode(0o600) }

        it 'lists the schedule precisely' do
          expect(subject.content).to match /\A0,15,30,45 \* \* \* \* root \/usr\/bin\/logrotate-cron\Z/
        end
      end
    end

    describe 'default su directive' do
      describe file('/etc/logrotate.d/default_su_directive') do
        it 'does `su root root` after any leading comments' do
          expect(subject.content).to match /\A(#.*\n)*su root root\Z/
        end
      end
    end
  end
end
