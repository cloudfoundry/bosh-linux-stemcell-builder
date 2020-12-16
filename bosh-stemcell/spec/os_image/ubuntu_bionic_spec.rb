require 'bosh/stemcell/arch'
require 'spec_helper'
require 'shellout_types/file'

describe 'Ubuntu 18.04 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an os with chrony'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'an Ubuntu-based OS image'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  describe package('rpm') do
    it { should_not be_installed }
  end

  describe service('remount-rootdir-as-rprivate') do
    it { should be_enabled }
  end

  context 'The system must limit the ability of processes to have simultaneous write and execute access to memory. (stig: V-38597)' do
    # Ubuntu relies on the system's hardware NX capabilities, or emulates NX if the hardware does not support it.
    # Ubuntu has had this capability since v 11.04
    # https://wiki.ubuntu.com/Security/Features#nx
    describe command('lsb_release -r') do
      it 'should run an os that emulates or uses things' do
        major_version = subject.stdout.match(/Release:\s+(\d+)(\.\d+)?/)[1].to_i
        expect(major_version).to be > 11
      end
    end
  end

  describe service('systemd-networkd') do
    it { should be_enabled }
  end

  describe 'base_apt' do
    describe file('/etc/apt/sources.list') do
      its(:content) { should match 'deb http://archive.ubuntu.com/ubuntu bionic main universe multiverse' }
      its(:content) { should match 'deb http://archive.ubuntu.com/ubuntu bionic-updates main universe multiverse' }
      its(:content) { should match 'deb http://security.ubuntu.com/ubuntu bionic-security main universe multiverse' }
    end

    describe file('/lib/systemd/system/runit.service') do
      it { should be_file }
      its(:content) { should match 'Restart=always' }
      its(:content) { should match 'KillMode=process' }
    end
  end

  context 'installed by base_ubuntu_packages' do
    describe file('/sbin/rescan-scsi-bus') do
      it { should be_file }
      it { should be_executable }
    end

    context 'zfs' do
      %w[
       /lib/modules/*/kernel/zfs/
        /usr/src/linux-headers-*/zfs
      ].each do |folder|
        describe file(folder) do
          it { should_not be_directory }
        end
      end
    end
  end

  context 'installed by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'only allow 3DES and AES series ciphers (stig: V-38617)' do
      ciphers = %w[
        aes256-gcm@openssh.com
        aes128-gcm@openssh.com
        aes256-ctr
        aes192-ctr
        aes128-ctr
      ].join(',')
      expect(sshd_config.content).to match(/^Ciphers #{ciphers}$/)
    end

    it 'allows only secure HMACs and the weaker SHA1 HMAC required by golang ssh lib' do
      macs = %w[
        hmac-sha2-512-etm@openssh.com
        hmac-sha2-256-etm@openssh.com
        umac-128-etm@openssh.com
        hmac-sha2-512
        hmac-sha2-256
        umac-128@openssh.com
      ].join(',')
      expect(sshd_config.content).to match(/^MACs #{macs}$/)
    end
  end

  context 'installed by system_grub' do
    %w[
      grub2
    ].each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
    %w[unicode.pf2 menu.lst gfxblacklist.txt].each do |grub_stage|
      describe file("/boot/grub/#{grub_stage}") do
        it { should be_file }
      end
    end
  end

  context 'installed by bosh_user' do
    describe file('/etc/passwd') do
      it { should be_file }
      its(:content) { should match '/home/vcap:/bin/bash' }
    end
  end

  context 'symlinked by vim_tiny' do
    describe file('/usr/bin/vim') do
      it { should be_linked_to '/usr/bin/vim.tiny' }
    end
  end

  context 'configured by cron_config' do
    describe file '/etc/cron.daily/man-db' do
      it { should_not be_file }
    end

    describe file '/etc/cron.weekly/man-db' do
      it { should_not be_file }
    end

    describe file '/etc/apt/apt.conf.d/02periodic' do
      its(:content) { should match <<~EOF }
        APT::Periodic {
          Enable "0";
        }
EOF
    end
  end

  context 'overriding control alt delete (stig: V-38668)' do
    describe file('/etc/init/control-alt-delete.override') do
      it { should be_file }
      its(:content) { should match 'exec /usr/bin/logger -p security.info "Control-Alt-Delete pressed"' }
    end
  end

  context 'package signature verification (stig: V-38462) (stig: V-38483)' do
    # verify default behavior was not changed
    describe command('grep -R AllowUnauthenticated /etc/apt/apt.conf.d/') do
      its (:stdout) { should eq('') }
    end
  end

  context 'official Ubuntu gpg key is installed (stig: V-38476)' do
    describe command('apt-key list') do
      its (:stdout) { should include('Ubuntu Archive Automatic Signing Key') }
    end
  end

  context 'PAM configuration' do
    describe file('/lib/x86_64-linux-gnu/security/pam_cracklib.so') do
      it { should be_file }
    end

    describe file('/etc/pam.d/common-password') do
      it'must prohibit the reuse of passwords within twenty-four iterations (stig: V-38658)' do
        expect(subject.content).to match /password.*pam_unix\.so.*remember=24/
      end

      it'must prohibit new passwords shorter than 14 characters (stig: V-38475)' do
        expect(subject.content).to match /password.*pam_unix\.so.*minlen=14/
      end

      it'must use the cracklib library to set correct password requirements (CIS-9.2.1)' do
        expect(subject.content).to match /password.*pam_cracklib\.so.*retry=3.*minlen=14.*dcredit=-1.*ucredit=-1.*ocredit=-1.*lcredit=-1/
      end
    end

    describe file('/etc/pam.d/common-account') do
      it 'must reset the tally of a user after successful login, esp. `sudo` (stig: V-38573)' do
        expect(subject.content).to match /account.*required.*pam_tally2\.so/
      end
    end

    describe file('/etc/pam.d/common-auth') do
      it'must restrict a user account after 3 failed login attempts (stig: V-38573)' do
        expect(subject.content).to match /auth.*pam_tally2\.so.*deny=3/
      end
    end
  end

  # V-38498 and V-38495 are the package defaults and cannot be configured
  context 'ensure auditd is installed (stig: V-38498) (stig: V-38495)' do
    describe package('auditd') do
      it { should be_installed }
    end
  end

  context 'ensure auditd file permissions and ownership (stig: V-38663) (stig: V-38664) (stig: V-38665)' do
    [[0o644, '/usr/share/lintian/overrides/auditd'],
     [0o755, '/usr/bin/auvirt'],
     [0o755, '/usr/bin/ausyscall'],
     [0o755, '/usr/bin/aulastlog'],
     [0o755, '/usr/bin/aulast'],
     [0o750, '/var/log/audit'],
     [0o755, '/sbin/aureport'],
     [0o755, '/sbin/auditd'],
     [0o755, '/sbin/autrace'],
     [0o755, '/sbin/ausearch'],
     [0o755, '/sbin/augenrules'],
     [0o755, '/sbin/auditctl'],
     [0o755, '/sbin/audispd'],
     [0o750, '/etc/audisp'],
     [0o750, '/etc/audisp/plugins.d'],
     [0o640, '/etc/audisp/plugins.d/af_unix.conf'],
     [0o640, '/etc/audisp/plugins.d/syslog.conf'],
     [0o640, '/etc/audisp/audispd.conf'],
     [0o755, '/etc/init.d/auditd'],
     [0o750, '/etc/audit'],
     [0o750, '/etc/audit/rules.d'],
     [0o640, '/etc/audit/rules.d/audit.rules'],
     [0o640, '/etc/audit/audit.rules'],
     [0o640, '/etc/audit/auditd.conf'],
     [0o644, '/etc/default/auditd'],
     [0o644, '/lib/systemd/system/auditd.service']].each do |tuple|
      describe file(tuple[1]) do
        its(:owner) { should eq('root') }
        its(:mode)  { should eq(tuple[0]) }
        its(:group) { should eq('root') }
      end
    end
  end

  context 'auditd is configured to use augenrules' do
    describe file('/etc/systemd/system/auditd.service') do
      it { should be_file }
      its(:content) { should match(/^ExecStartPost=-\/sbin\/augenrules --load$/) }
    end
  end

  context 'ensure audit package file have unmodified contents (stig: V-38637)' do
    # ignore auditd.conf, auditd, and audit.rules since we modify these files in
    # other stigs
    describe command("dpkg -V audit | grep -v 'auditd.conf' | grep -v 'default/auditd' | grep -v 'audit.rules' | grep -v 'syslog.conf' | grep '^..5'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure sendmail is removed (stig: V-38671)' do
    describe command('dpkg -s sendmail') do
      it 'complains about non-installed sendmail' do
        expect(subject.stderr).to include 'dpkg-query: package \'sendmail\' is not installed and no information is available'
      end
    end
  end

  describe service('xinetd') do
    it('should be disabled (stig: V-38582)') { should_not be_enabled }
  end

  context 'ensure cron is installed and enabled (stig: V-38605)' do
    describe package('cron') do
      it('should be installed') { should be_installed }
    end

    describe service('cron') do
      it('should be enabled') { should be_enabled }
    end
  end

  context 'ensure ypbind is not running (stig: V-38604)' do
    describe package('nis') do
      it { should_not be_installed }
    end
    describe file('/var/run/ypbind.pid') do
      it { should_not be_file }
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

  context 'display the number of unsuccessful logon/access attempts since the last successful logon/access (stig: V-51875)' do
    describe file('/etc/pam.d/common-password') do
      its(:content) { should match /session     required      pam_lastlog\.so showfailed/ }
    end
  end

  context 'ensure whoopsie and apport are not installed (CIS-4.1)' do
    describe package('apport') do
      it { should_not be_installed }
    end
    describe package('whoopsie') do
      it { should_not be_installed }
    end
  end

  context 'restrict access to the su command CIS-9.5' do
    describe command('grep "^\s*auth\s*required\s*pam_wheel.so\s*use_uid" /etc/pam.d/su') do
      it('exits 0') { expect(subject.exit_status).to eq(0) }
    end
    describe user('vcap') do
      it { should exist }
      it { should be_in_group 'sudo' }
    end
  end

  describe 'logging and audit startup script' do
    describe file('/var/vcap/bosh/bin/bosh-start-logging-and-auditing') do
      it { should be_file }
      it { should be_executable }
      its(:content) { should match('service auditd start') }
    end
  end

  describe 'allowed user accounts' do
    describe file('/etc/passwd') do
      its(:content) { should eql(<<HERE) }
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:100:102:systemd Network Management,,,:/run/systemd/netif:/usr/sbin/nologin
systemd-resolve:x:101:103:systemd Resolver,,,:/run/systemd/resolve:/usr/sbin/nologin
syslog:x:102:106::/home/syslog:/usr/sbin/nologin
messagebus:x:103:107::/nonexistent:/usr/sbin/nologin
_apt:x:104:65534::/nonexistent:/usr/sbin/nologin
uuidd:x:105:109::/run/uuidd:/usr/sbin/nologin
_chrony:x:106:110:Chrony daemon,,,:/var/lib/chrony:/usr/sbin/nologin
sshd:x:107:65534::/run/sshd:/usr/sbin/nologin
vcap:x:1000:1000:BOSH System User:/home/vcap:/bin/bash
HERE
    end

    describe file('/etc/shadow') do
      shadow_match = Regexp.new <<'END_SHADOW', [Regexp::MULTILINE]
\Aroot:(.+):(\d{5}):0:99999:7:::
daemon:\*:(\d{5}):0:99999:7:::
bin:\*:(\d{5}):0:99999:7:::
sys:\*:(\d{5}):0:99999:7:::
sync:\*:(\d{5}):0:99999:7:::
games:\*:(\d{5}):0:99999:7:::
man:\*:(\d{5}):0:99999:7:::
lp:\*:(\d{5}):0:99999:7:::
mail:\*:(\d{5}):0:99999:7:::
news:\*:(\d{5}):0:99999:7:::
uucp:\*:(\d{5}):0:99999:7:::
proxy:\*:(\d{5}):0:99999:7:::
www-data:\*:(\d{5}):0:99999:7:::
backup:\*:(\d{5}):0:99999:7:::
list:\*:(\d{5}):0:99999:7:::
irc:\*:(\d{5}):0:99999:7:::
gnats:\*:(\d{5}):0:99999:7:::
nobody:\*:(\d{5}):0:99999:7:::
systemd-network:\*:(\d{5}):0:99999:7:::
systemd-resolve:\*:(\d{5}):0:99999:7:::
syslog:\*:(\d{5}):0:99999:7:::
messagebus:\*:(\d{5}):0:99999:7:::
_apt:\*:(\d{5}):0:99999:7:::
uuidd:(.+):(\d{5}):0:99999:7:::
_chrony:(.+):(\d{5}):0:99999:7:::
sshd:\*:(\d{5}):0:99999:7:::
vcap:(.+):(\d{5}):1:99999:7:::\Z
END_SHADOW

      its(:content) { should match(shadow_match) }
    end

    describe file('/etc/group') do
      its(:content) { should eql(<<HERE) }
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:vcap
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:vcap
fax:x:21:
voice:x:22:
cdrom:x:24:vcap
floppy:x:25:vcap
tape:x:26:
sudo:x:27:vcap
audio:x:29:vcap
dip:x:30:vcap
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
gnats:x:41:
shadow:x:42:
utmp:x:43:
video:x:44:vcap
sasl:x:45:
plugdev:x:46:vcap
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
systemd-journal:x:101:
systemd-network:x:102:
systemd-resolve:x:103:
input:x:104:
crontab:x:105:
syslog:x:106:
messagebus:x:107:
netdev:x:108:
uuidd:x:109:
_chrony:x:110:
ssh:x:111:
admin:x:999:vcap
vcap:x:1000:syslog
bosh_sshers:x:1001:vcap
bosh_sudoers:x:1002:
HERE
    end

    describe file('/etc/gshadow') do
      its(:content) { should eql(<<HERE) }
root:*::
daemon:*::
bin:*::
sys:*::
adm:*::vcap
tty:*::
disk:*::
lp:*::
mail:*::
news:*::
uucp:*::
man:*::
proxy:*::
kmem:*::
dialout:*::vcap
fax:*::
voice:*::
cdrom:*::vcap
floppy:*::vcap
tape:*::
sudo:*::vcap
audio:*::vcap
dip:*::vcap
www-data:*::
backup:*::
operator:*::
list:*::
irc:*::
src:*::
gnats:*::
shadow:*::
utmp:*::
video:*::vcap
sasl:*::
plugdev:*::vcap
staff:*::
games:*::
users:*::
nogroup:*::
systemd-journal:!::
systemd-network:!::
systemd-resolve:!::
input:!::
crontab:!::
syslog:!::
messagebus:!::
netdev:!::
uuidd:!::
_chrony:!::
ssh:!::
admin:!::vcap
vcap:!::syslog
bosh_sshers:!::vcap
bosh_sudoers:!::
HERE
    end
  end
end
