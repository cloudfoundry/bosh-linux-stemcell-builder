require 'spec_helper'

describe 'CentOS 7 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an os with ntpdate'
  it_behaves_like 'a CentOS or RHEL based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_centos' do
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
      it { should be_file }
      its(:content) { should match (/CentOS Linux release 7\./)} # example: `CentOS Linux release 7.7.1908 (Core)`
    end

    describe file('/etc/centos-release') do
      # NOTE: This file MUST exist, or else the automation will mis-identify the OS-type of this stemcell.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      # NOTE: for centos, the '/etc/centos-release' file appears to be a soft link of the '/etc/redhat-release' file
      # NOTE: It is OK for both this file and the one above to both exist (for centos stemcells),
      # since the OS-type-inference code gives higher precedence to this file.
      it { should be_file }
      its(:content) { should match (/CentOS Linux release 7\./)} # example: `CentOS Linux release 7.7.1908 (Core)`
    end

    %w(
      centos-release
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
      net-tools
      openssl
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

    describe file('/usr/sbin/ifconfig') do
      it { should be_executable }
    end
  end

  context 'installed by system_grub' do
    describe package('grub2-tools') do
      it { should be_installed, -> { "Message: #{subject.last_message} #{subject.last_error}" } }
    end
  end

  context 'required initramfs modules' do
    describe command("/usr/lib/dracut/skipcpio /boot/initramfs-3.10.*.el7.x86_64.img | zcat | cpio -t | grep '/lib/modules/3.10.*.el7.x86_64'") do

      modules = [
        #ata
          'ata_generic', 'pata_acpi',
        #block
          'floppy', 'loop', 'brd',
        #xen
          'xen-blkfront',
        #hv
          'hv_vmbus','hv_storvsc', 'hv_vmbus',
        #virtio
          'virtio_blk', 'virtio_net', 'virtio_pci', 'virtio_scsi',
        #vmware fusion
          'mptspi', 'mptbase', 'mptscsih','mpt2sas', 'mpt3sas',
        #scsci
          '3w-9xxx',
          '3w-sas',
          'aic79xx',
          'arcmsr',
          'bfa',
          'fnic',
          'hpsa',
          'hptiop',
          'initio',
          'isci',
          'libsas',
          'lpfc',
          'megaraid_sas',
          'mtip32xx',
          'mvsas',
          'mvumi',
          'nvme',
          'pm80xx',
          'pmcraid',
          'qla2xxx',
          'qla4xxx',
          'raid_class',
          'stex',
          'sx8',
          'vmw_pvscsi',
        #fs
          'cachefiles',
          'cifs',
          'cramfs',
          'dlm',
          'libore',
          'fscache',
          'grace',
          'nfs_acl',
          'fuse',
          'gfs2',
          'isofs',
          'nfs',
          'nfsd',
          'nfsv3',
          'nfsv4',
          'overlay',
          'ramoops',
          'squashfs',
          'udf',
          'btrfs',
          'ext4',
          'jbd2',
          'mbcache',
          'xfs'
      ]

      modules.each do |foo|
        its (:stdout) { should match(/\/#{foo}\.ko/) }
      end
    end
  end

  context 'official Centos gpg key is installed (stig: V-38476)' do
    describe command('rpm -qa gpg-pubkey* 2>/dev/null | xargs rpm -qi 2>/dev/null') do
      its (:stdout) { should include('CentOS 7 Official Signing Key') }
    end
  end

  context 'ensure xinetd is not installed nor enabled (stig: V-38582)' do
    describe package('xinetd') do
      it('should not be installed') { should_not be_installed }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/xinetd.service') do
      it { should_not be_file }
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

    end
  end

  context 'bosh_audit_centos' do
    describe file('/etc/audit/rules.d/audit.rules') do
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/lib64\/dbus-1\/dbus-daemon-launch-helper -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/openssh\/ssh-keysign -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/krb5_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/ldap_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/p11_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/proxy_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/selinux_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/utempter\/utempter -k privileged/ }
    end
  end
end
