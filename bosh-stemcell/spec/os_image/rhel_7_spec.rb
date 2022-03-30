require 'spec_helper'

describe 'RHEL 7 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an os with ntpdate'
  it_behaves_like 'a CentOS or RHEL based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_rhel' do
    describe command('rct cat-cert /etc/pki/product/69.pem') do
      its (:stdout) { should match /rhel-7-server/ }
    end

    describe file('/etc/os-release') do
      # SEE: https://www.freedesktop.org/software/systemd/man/os-release.html
      it { should be_file }
      its(:content) { should include ('ID="centos"')}
      its(:content) { should include ('NAME="CentOS Linux"')}
      its(:content) { should include ('VERSION_ID="7')} # example: `VERSION_ID="7"`
      its(:content) { should include ('VERSION="7')} # example: `VERSION="7 (Core)"`
      its(:content) { should include ('PRETTY_NAME="CentOS Linux 7')} # example: `PRETTY_NAME="CentOS Linux 7 (Core)"`
    end

    describe file('/etc/redhat-release') do
      # NOTE: This file MUST exist, or else the automation will mis-identify the OS-type of this stemcell.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      it { should be_file }
      its(:content) { should match (/Red Hat Enterprise Linux release 7\./)}
    end

    describe file('/etc/centos-release') do
      # NOTE: The stemcell builder automation infers the OS-type based on the existence of specific `/etc/*-release` files,
      # so this file MUST NOT exist in this stemcell,
      # or else the automation will incorrectly identify this stemcell as a CentOS stemcell.
      # NOTE: It is NOT OK for both this file and the one above to both exist (for RHEL stemcells),
      # since the OS-type-inference code gives higher precedence to this file.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      it { should_not be_file }
    end

    %w(
      redhat-release-server
      epel-release
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'installed by base_centos_packages' do
    # explicitly installed packages. see: stemcell_builder/stages/base_centos_packages/apply.sh
    %w(
      apparmor-utils
      bind9-host
      bison
      bzip2-devel
      cloud-utils-growpart
      cmake
      curl
      dhclient
      dnsutils
      e2fsprogs
      flex
      gdb
      gdisk
      iptables
      iputils-arping
      libaio1
      libcap-devel
      libcap2-bin
      libcurl3
      libcurl3-dev
      libncurses5-devs
      libuuid-devel
      libxml2
      libxml2-devel
      libxslt
      libxslt-devel
      libyaml-devel
      lsof
      NetworkManager
      nfs-common
      nmap-ncat
      nvme-cli
      openssh-server
      openssl-devel
      parted
      psmisc
      readline-devel
      rsync
      strace
      sudo
      sysstat
      tcpdump
      traceroute
      unzip
      wget
      xfsprogs
      zip
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    # implicitly installed packages.
    %w(
      cronie-anacron
      glibc-static
      openssl
      quota
      rpm-build
      rpmdevtools
      rsyslog
      rsyslog-relp
      rsyslog-gnutls
      rsyslog-mmjsonparse
      runit
      systemd
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'ctrl-alt-del restrictions' do
    # NOTE: stig V-230531 explicitly targets RHEL 8, but the vulnerability affects RHEL 7.4 and later.
    context 'overriding control alt delete burst action (stig: V-230531)' do
      describe file('/etc/systemd/system.conf') do
        it { should be_file }
        its(:content) { should match /^CtrlAltDelBurstAction=none$/ }
      end
    end
  end

  context 'official Red Hat gpg key is installed (stig: V-38476)' do
    describe command('rpm -qa gpg-pubkey* 2>/dev/null | xargs rpm -qi 2>/dev/null') do
      # SEE: https://access.redhat.com/security/team/key
      it('shows the Red Hat RHEL 6,7,8 release key is installed') { expect(subject.stdout).to include('Red Hat, Inc. (release key 2) <security@redhat.com>') }
      it('shows the Red Hat RHEL 5,6,7 disaster recovery key is installed') { expect(subject.stdout).to include('Red Hat, Inc. (auxiliary key) <security@redhat.com>') }

      # SEE: https://getfedora.org/security/
      # SEE: https://dl.fedoraproject.org/pub/epel/
      it('shows the Fedora EPEL 7 key is installed') { expect(subject.stdout).to include('Fedora EPEL (7) <epel@fedoraproject.org>') }
    end
  end

  context 'ensure auditd file permissions and ownership (stig: V-38663) (stig: V-38664) (stig: V-38665)' do
    [[0o755, '/usr/bin/auvirt'],
     [0o755, '/usr/bin/ausyscall'],
     [0o755, '/usr/bin/aulastlog'],
     [0o755, '/usr/bin/aulast'],
     [0o700, '/var/log/audit'],
     [0o755, '/sbin/aureport'],
     [0o755, '/sbin/auditd'],
     [0o750, '/sbin/autrace'],
     [0o755, '/sbin/ausearch'],
     [0o755, '/sbin/augenrules'],
     [0o755, '/sbin/auditctl'],
     [0o755, '/sbin/audispd'],
     [0o750, '/etc/audisp'],
     [0o750, '/etc/audisp/plugins.d'],
     [0o640, '/etc/audisp/plugins.d/af_unix.conf'],
     [0o640, '/etc/audisp/plugins.d/syslog.conf'],
     [0o640, '/etc/audisp/audispd.conf'],
     [0o750, '/etc/audit'],
     [0o750, '/etc/audit/rules.d'],
     [0o640, '/etc/audit/rules.d/audit.rules'],
     [0o640, '/etc/audit/auditd.conf'],
     [0o644, '/lib/systemd/system/auditd.service']].each do |tuple|
      describe file(tuple[1]) do
        its(:owner) { should eq('root') }
        its(:mode)  { should eq(tuple[0]) }
        its(:group) { should eq('root') }
      end
    end
  end

  describe 'allowed user accounts' do
    describe file('/etc/passwd') do
      passwd_match_raw = <<HERE
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
adm:x:3:4:adm:/var/adm:/sbin/nologin
lp:x:4:7:lp:/var/spool/lpd:/sbin/nologin
sync:x:5:0:sync:/sbin:/bin/sync
shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown
halt:x:7:0:halt:/sbin:/sbin/halt
mail:x:8:12:mail:/var/spool/mail:/sbin/nologin
operator:x:11:0:operator:/root:/sbin/nologin
games:x:12:100:games:/usr/games:/sbin/nologin
ftp:x:14:50:FTP User:/var/ftp:/sbin/nologin
nobody:x:99:99:Nobody:/:/sbin/nologin
systemd-network:x:192:192:systemd Network Management:/:/sbin/nologin
dbus:x:81:81:System message bus:/:/sbin/nologin
polkitd:x:999:998:User for polkitd:/:/sbin/nologin
rpc:x:32:32:Rpcbind Daemon:/var/lib/rpcbind:/sbin/nologin
abrt:x:173:173::/etc/abrt:/sbin/nologin
libstoragemgmt:x:998:997:daemon account for libstoragemgmt:/var/run/lsm:/sbin/nologin
tcpdump:x:72:72::/:/sbin/nologin
chrony:x:997:996::/var/lib/chrony:/sbin/nologin
ntp:x:38:38::/etc/ntp:/sbin/nologin
tss:x:59:59:Account used by the trousers package to sandbox the tcsd daemon:/dev/null:/sbin/nologin
sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin
vcap:x:1000:1000:BOSH System User:/home/vcap:/bin/bash
syslog:x:996:993::/home/syslog:/sbin/nologin
HERE
      passwd_match_lines = passwd_match_raw.split(/\n+/)

      its(:content_as_lines) { should match_array(passwd_match_lines)}
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(passwd_match_lines), -> { "full content: '#{subject.content}'" } }
    end

    describe file('/etc/shadow') do
      shadow_match_raw = <<HERE
root:(.+):\\d{5}:0:99999:7:::
bin:\\*:\\d{5}:0:99999:7:::
daemon:\\*:\\d{5}:0:99999:7:::
adm:\\*:\\d{5}:0:99999:7:::
lp:\\*:\\d{5}:0:99999:7:::
sync:\\*:\\d{5}:0:99999:7:::
shutdown:\\*:\\d{5}:0:99999:7:::
halt:\\*:\\d{5}:0:99999:7:::
mail:\\*:\\d{5}:0:99999:7:::
operator:\\*:\\d{5}:0:99999:7:::
games:\\*:\\d{5}:0:99999:7:::
ftp:\\*:\\d{5}:0:99999:7:::
nobody:\\*:\\d{5}:0:99999:7:::
systemd-network:!!:\\d{5}::::::
dbus:!!:\\d{5}::::::
polkitd:!!:\\d{5}::::::
rpc:!!:\\d{5}:0:99999:7:::
abrt:!!:\\d{5}::::::
libstoragemgmt:!!:\\d{5}::::::
tcpdump:!!:\\d{5}::::::
chrony:!!:\\d{5}::::::
ntp:!!:\\d{5}::::::
tss:!!:\\d{5}::::::
sshd:!!:\\d{5}::::::
vcap:(.+):\\d{5}:1:99999:7:::
syslog:!!:\\d{5}::::::
HERE

      shadow_match_lines = shadow_match_raw.split(/\n+/).map { |l| Regexp.new("^#{l}$") }
      its(:content_as_lines) { should match_array(shadow_match_lines) }
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(shadow_match_lines), -> { "full content: '#{subject.content}'" } }
    end

    describe file('/etc/group') do

      group_raw = <<HERE
root:x:0:
bin:x:1:
daemon:x:2:
sys:x:3:
adm:x:4:vcap
tty:x:5:
disk:x:6:
lp:x:7:
mem:x:8:
kmem:x:9:
wheel:x:10:vcap
cdrom:x:11:vcap
mail:x:12:
man:x:15:
dialout:x:18:vcap
floppy:x:19:vcap
games:x:20:
tape:x:33:
video:x:39:vcap
ftp:x:50:
lock:x:54:
audio:x:63:vcap
nobody:x:99:
users:x:100:
utmp:x:22:
utempter:x:35:
input:x:999:
systemd-journal:x:190:
systemd-network:x:192:
dbus:x:81:
polkitd:x:998:
rpc:x:32:
abrt:x:173:
libstoragemgmt:x:997:
tcpdump:x:72:
stapusr:x:156:
stapsys:x:157:
stapdev:x:158:
chrony:x:996:
slocate:x:21:
ntp:x:38:
ssh_keys:x:995:
tss:x:59:
sshd:x:74:
admin:x:994:vcap
vcap:x:1000:syslog
bosh_sshers:x:1001:vcap
bosh_sudoers:x:1002:
syslog:x:993:
HERE
      group_lines = group_raw.split(/\n+/)
      its(:content_as_lines) { should match_array(group_lines)}
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(group_lines), -> { "full content: '#{subject.content}'" } }
    end

    describe file('/etc/gshadow') do

      gshadow_raw = <<HERE
root:*::
bin:*::
daemon:*::
sys:*::
adm:*::vcap
tty:*::
disk:*::
lp:*::
mem:*::
kmem:*::
wheel:*::vcap
cdrom:*::vcap
mail:*::
man:*::
dialout:*::vcap
floppy:*::vcap
games:*::
tape:*::
video:*::vcap
ftp:*::
lock:*::
audio:*::vcap
nobody:*::
users:*::
utmp:!::
utempter:!::
input:!::
systemd-journal:!::
systemd-network:!::
dbus:!::
polkitd:!::
rpc:!::
abrt:!::
libstoragemgmt:!::
tcpdump:!::
stapusr:!::
stapsys:!::
stapdev:!::
chrony:!::
slocate:!::
ntp:!::
ssh_keys:!::
tss:!::
sshd:!::
admin:!::vcap
vcap:!::syslog
bosh_sshers:!::vcap
bosh_sudoers:!::
syslog:!::
HERE

      gshadow_lines = gshadow_raw.split(/\n+/)
      its(:content_as_lines) { should match_array(gshadow_lines)}
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(gshadow_lines), -> { "full content: '#{subject.content}'" } }
    end
  end
end
