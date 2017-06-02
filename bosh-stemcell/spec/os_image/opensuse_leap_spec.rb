require 'spec_helper'

describe 'openSUSE leap OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'a openSUSE based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel 3.x based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_opensuse' do
    describe file('/etc/SuSE-release') do
      it { should be_file }
    end

    describe file('/etc/locale.conf') do
      it { should be_file }
      its(:content) { should match 'en_US.UTF-8' }
    end
  end

  context 'package signature verification (stig: V-38462)' do
    describe command('grep nosignature /etc/rpmrc /usr/lib/rpm/rpmrc /usr/lib/rpm/redhat/rpmrc ~root/.rpmrc') do
      its(:stdout) { should_not include('nosignature') }
    end
  end

  context 'display the number of unsuccessful logon/access attempts since the last successful logon/access (stig: V-51875)' do
    describe file('/etc/pam.d/common-password') do
      its(:content){ should match /session required\tpam_lastlog\.so  showfailed/ }
    end
  end

  context 'official Centos gpg key is installed (stig: V-38476)' do
    describe command('rpm -qa gpg-pubkey* 2>/dev/null | xargs rpm -qi 2>/dev/null') do
      its(:stdout) { should include('SuSE Package Signing Key') }
    end
  end

  context 'gpgcheck must be enabled (stig: V-38483)' do
    describe file('/etc/zypp/zypp.conf') do
      its(:content) { should match /^gpgcheck.*=.*on$/ }
    end
  end

  context 'ensure sendmail is removed (stig: V-38671)' do
    describe command('rpm -q sendmail') do
      its(:stdout) { should include ('package sendmail is not installed')}
    end
  end

  context 'ensure cron is installed and enabled (stig: V-38605)' do
    describe package('cronie') do
      it('should be installed') { should be_installed }
    end

    describe file('/etc/systemd/system/default.target') do
      it { should be_file }
      it { should be_linked_to('/usr/lib/systemd/system/multi-user.target') }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/cron.service') do
      it { should be_file }
      its(:content) { should match /^ExecStart=\/usr\/sbin\/cron/ }
    end
  end

  context 'ensure auditd is installed (stig: V-38498) (stig: V-38495)' do
    describe package('audit') do
      it { should be_installed }
    end
  end

  context 'ensure audit package file have correct permissions (stig: V-38663)' do
    describe command('rpm -V audit | grep ^.M') do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure audit package file have correct owners (stig: V-38664)' do
    describe command("rpm -V audit | grep '^.....U'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure audit package file have correct groups (stig: V-38665)' do
    describe command("rpm -V audit | grep '^......G'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure audit package file have unmodified contents (stig: V-38637)' do
    # ignore auditd.conf, and audit.rules since we modify these files in
    # other stigs
    describe command("rpm -V audit | grep -v 'auditd.conf' | grep -v 'audit.rules' | grep -v 'syslog.conf' | grep '^..5'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'The system must limit the ability of processes to have simultaneous write and execute access to memory. (stig: V-38597)' do
    # openSUSE relies on the system's hardware NX capabilities, or emulates NX if the hardware does
    # not support it. openSUSE has had this capability since version 9
    describe file('/etc/os-release') do
      it 'should run an os that emulates or uses things' do
        major_version = subject.content.match(/VERSION=.*?(\d+?)\.(\d+)/)[1].to_i
        expect(major_version).to be >= 9
      end
    end
  end

  context 'ensure ypserv is not installed (stig: V-38603)' do
    describe package('nis') do
      it { should_not be_installed }
    end
  end

  context 'ensure snmp is not installed (stig: V-38660) (stig: V-38653)' do
    describe package('snmp') do
      it { should_not be_installed }
    end
  end

  context 'ensure ypbind is not running (stig: V-38604)' do
    describe package('ypbind') do
      it('should not be installed') { should_not be_installed }
    end

    describe file('/etc/systemd/system/default.target') do
      it { should be_file }
      it { should be_linked_to('/usr/lib/systemd/system/multi-user.target') }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/ypbind.service') do
      it { should_not be_file }
    end
  end

  describe 'logging and audit startup script' do
    describe file('/var/vcap/bosh/bin/bosh-start-logging-and-auditing') do
      it { should be_file }
      it { should be_executable }
      its(:content) { should match('service auditd start') }
    end
  end

  context 'gdisk' do
    it 'should be installed' do
      expect(package('gptfdisk')).to be_installed
    end
  end

end
