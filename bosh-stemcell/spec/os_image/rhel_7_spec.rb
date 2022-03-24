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

  context 'installed by system_grub' do
    describe package('grub2-tools') do
      it { should be_installed }
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
end
