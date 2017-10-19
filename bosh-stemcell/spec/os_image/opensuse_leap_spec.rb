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

  context 'official SuSE gpg key is installed (stig: V-38476)' do
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

  describe 'allowed user accounts' do
    describe file('/etc/passwd') do
      it "only has login shells for root and vcap" do
        passwd_match = Regexp.new <<'END_PASSWD', [Regexp::MULTILINE]
bin:x:[1-9][0-9]*:[1-9][0-9]*+:bin:/bin:/bin/false
daemon:x:[1-9][0-9]*:[1-9][0-9]*+:Daemon:/sbin:/bin/false
ftp:x:[1-9][0-9]*:[1-9][0-9]*+:FTP account:/srv/ftp:/bin/false
games:x:[1-9][0-9]*:[1-9][0-9]*+:Games account:/var/games:/bin/false
lp:x:[1-9][0-9]*:[1-9][0-9]*+:Printing daemon:/var/spool/lpd:/bin/false
mail:x:[1-9][0-9]*:[1-9][0-9]*+:Mailer daemon:/var/spool/clientmqueue:/bin/false
man:x:[1-9][0-9]*:[1-9][0-9]*+:Manual pages viewer:/var/cache/man:/bin/false
messagebus:x:[1-9][0-9]*:[1-9][0-9]*+:User for D-Bus:/run/dbus:/bin/false
news:x:[1-9][0-9]*:[1-9][0-9]*+:News system:/etc/news:/bin/false
nobody:x:[1-9][0-9]*:[1-9][0-9]*+:nobody:/var/lib/nobody:/bin/false
ntp:x:[1-9][0-9]*:[1-9][0-9]*+:NTP daemon:/var/lib/ntp:/bin/false
pesign:x:[1-9][0-9]*:[1-9][0-9]*+:PE-COFF signing daemon:/var/lib/pesign:/bin/false
polkitd:x:[1-9][0-9]*:[1-9][0-9]*+:User for polkitd:/var/lib/polkit:/sbin/nologin
root:x:0:0:root:/root:/bin/bash
rpc:x:[1-9][0-9]*:[1-9][0-9]*+:user for rpcbind:/var/lib/empty:/sbin/nologin
sshd:x:[1-9][0-9]*:[1-9][0-9]*+:SSH daemon:/var/lib/sshd:/bin/false
syslog:x:[1-9][0-9]*:[1-9][0-9]*+::/home/syslog:/bin/false
systemd-bus-proxy:x:[1-9][0-9]*:[1-9][0-9]*+:systemd Bus Proxy:/:/sbin/nologin
systemd-timesync:x:[1-9][0-9]*:[1-9][0-9]*+:systemd Time Synchronization:/:/sbin/nologin
uucp:x:[1-9][0-9]*:[1-9][0-9]*+:Unix-to-Unix CoPy system:/etc/uucp:/bin/false
vcap:x:[1-9][0-9]*:[1-9][0-9]*+:BOSH System User:/home/vcap:/bin/bash
wwwrun:x:[1-9][0-9]*:[1-9][0-9]*+:WWW daemon apache:/var/lib/wwwrun:/bin/false
END_PASSWD
        expect(subject.content.lines.sort.join).to match(passwd_match)
      end
    end

    describe file('/etc/shadow') do
      shadow_match = Regexp.new <<'END_SHADOW', [Regexp::MULTILINE]
\Abin:\*:\d{5}::::::
daemon:\*:\d{5}::::::
ftp:\*:\d{5}::::::
games:\*:\d{5}::::::
lp:\*:\d{5}::::::
mail:\*:\d{5}::::::
man:\*:\d{5}::::::
messagebus:!:\d{5}::::::
news:\*:\d{5}::::::
nobody:\*:\d{5}::::::
ntp:!:\d{5}::::::
pesign:!:\d{5}::::::
polkitd:!:\d{5}::::::
root:.+:\d{5}::::::
rpc:!:\d{5}::::::
sshd:!:\d{5}::::::
syslog:!:\d{5}::::::
systemd-bus-proxy:!!:\d{5}::::::
systemd-timesync:!!:\d{5}::::::
uucp:\*:\d{5}::::::
vcap:.+:\d{5}:1:99999:7:::
wwwrun:\*:\d{5}::::::\Z
END_SHADOW

      it "does not contain any password" do 
        expect(subject.content.lines.sort.join).to match(shadow_match) 
      end
    end

    describe file('/etc/group') do
      it "does not contain any passwords" do
        group_match = Regexp.new <<'END_GROUP', [Regexp::MULTILINE]
adm:x:[1-9][0-9]*:vcap
admin:x:[1-9][0-9]*:vcap
audio:x:[1-9][0-9]*:vcap
bin:x:[1-9][0-9]*:daemon
bosh_sshers:x:[1-9][0-9]*:vcap
bosh_sudoers:x:[1-9][0-9]*:
cdrom:x:[1-9][0-9]*:vcap
console:x:[1-9][0-9]*:
daemon:x:[1-9][0-9]*:
dialout:x:[1-9][0-9]*:vcap
dip:x:[1-9][0-9]*:vcap
disk:x:[1-9][0-9]*:
floppy:x:[1-9][0-9]*:vcap
ftp:x:[1-9][0-9]*:
games:x:[1-9][0-9]*:
input:x:[1-9][0-9]*:
kmem:x:[1-9][0-9]*:
lock:x:[1-9][0-9]*:
lp:x:[1-9][0-9]*:
mail:x:[1-9][0-9]*:
man:x:[1-9][0-9]*:
messagebus:x:[1-9][0-9]*:
modem:x:[1-9][0-9]*:
news:x:[1-9][0-9]*:
nobody:x:[1-9][0-9]*:
nogroup:x:[1-9][0-9]*:nobody
ntp:x:[1-9][0-9]*:
pesign:x:[1-9][0-9]*:
polkitd:x:[1-9][0-9]*:
public:x:[1-9][0-9]*:
root:x:0:
shadow:x:[1-9][0-9]*:
sshd:x:[1-9][0-9]*:
sys:x:[1-9][0-9]*:
syslog:!:[1-9][0-9]*:
systemd-bus-proxy:x:[1-9][0-9]*:
systemd-journal:x:[1-9][0-9]*:
systemd-timesync:x:[1-9][0-9]*:
tape:x:[1-9][0-9]*:
trusted:x:[1-9][0-9]*:
tty:x:[1-9][0-9]*:
users:x:[1-9][0-9]*:
utmp:x:[1-9][0-9]*:
uucp:x:[1-9][0-9]*:
vcap:x:[1-9][0-9]*:syslog
video:x:[1-9][0-9]*:vcap
wheel:x:[1-9][0-9]*:vcap
www:x:[1-9][0-9]*:
xok:x:[1-9][0-9]*:
END_GROUP
        expect(subject.content.lines.sort.join).to match(group_match)
      end
    end

    describe file('/etc/gshadow') do
      it "does not contain any passwords" do
         expected = <<HERE.lines
systemd-timesync:!!::
systemd-bus-proxy:!!::
systemd-journal:!!::
HERE
        expect(subject.content.lines).to match_array(expected)
      end
    end
  end
end

