require 'spec_helper'

describe 'RHEL 8 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an os with chrony'
  it_behaves_like 'a CentOS or RHEL based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_rhel' do
    describe command('rct cat-cert /etc/pki/product/69.pem') do
      its (:stdout) { should match /rhel-8/ }
    end

    describe file('/etc/os-release') do
      # SEE: https://www.freedesktop.org/software/systemd/man/os-release.html
      it { should be_file }
      its(:content) { should include ('ID="rhel"')}
      its(:content) { should include ('NAME="Red Hat Enterprise Linux"')}
      its(:content) { should include ('VERSION_ID="8')} # example: `VERSION_ID="8.5"`
      its(:content) { should include ('VERSION="8')} # example: `VERSION="8.5 (Ootpa)"`
      its(:content) { should include ('PRETTY_NAME="Red Hat Enterprise Linux 8.')} # example: `PRETTY_NAME="Red Hat Enterprise Linux 8.5 (Ootpa)"`
    end

    describe file('/etc/redhat-release') do
      # NOTE: This file MUST exist, or else the automation will mis-identify the OS-type of this stemcell.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      it { should be_file }
      its(:content) { should match (/Red Hat Enterprise Linux release 8\./)}
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
      redhat-release
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
      bind
      bind-utils
      bison
      bzip2-devel
      cloud-utils-growpart
      cmake
      curl
      dhcp-client
      e2fsprogs
      flex
      gdb
      gdisk
      iptables
      iputils
      libaio
      libcap
      libcap-devel
      libcurl
      libcurl-devel
      libuuid-devel
      libxml2
      libxml2-devel
      libxslt
      libxslt-devel
      libyaml-devel
      lsof
      ncurses-devel
      network-scripts
      NetworkManager
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
      it('shows the Red Hat RHEL 8 disaster recovery key is installed') do
        # NOTE: The Red Hat docs page (see link above) says that the RHEL 8 disaster recovery key (published 2018-06-27)
        # should be named 'Red Hat, Inc. (auxiliary key 2) <security@redhat.com>'.
        # However, with RHEL 8.5 we find a key with matching publish date and fingerprint,
        # but with a different name/packager (which matches the documented name of the RHEL 5,6,7 gpg key).
        # Based on the matching publish date and fingerprint, we have changed the spec
        # to match the observed name plus the publish date (instead of the documented name).
        # See the commit message associated with this comment for details.
        expect(subject.stdout).to include('Red Hat, Inc. (auxiliary key) <security@redhat.com>')
        expect(subject.stdout).to include('Build Date  : Wed 27 Jun 2018 12:33:57 AM UTC')
      end

      # SEE: https://getfedora.org/security/
      # SEE: https://dl.fedoraproject.org/pub/epel/
      it('shows the Fedora EPEL 8 key is installed') { expect(subject.stdout).to include('Fedora EPEL (8) <epel@fedoraproject.org>') }
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
     [0o750, '/etc/audit'],
     [0o750, '/etc/audit/plugins.d'],
     [0o640, '/etc/audit/plugins.d/af_unix.conf'],
     [0o640, '/etc/audit/plugins.d/syslog.conf'],
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

end
