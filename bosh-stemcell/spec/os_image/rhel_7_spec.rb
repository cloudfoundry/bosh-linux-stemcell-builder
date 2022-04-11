require 'spec_helper'

describe 'RHEL 7 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'a CentOS or RHEL based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_rhel' do
    describe command('rct cat-cert /etc/pki/product/69.pem') do
      its (:stdout) { should match /rhel-7-server/ }
    end

    describe file('/etc/centos-release') do
      it { should_not be_file }
    end

    describe file('/etc/locale.conf') do
      it { should be_file }
      its(:content) { should match 'en_US.UTF-8' }
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
    %w(
      apparmor-utils
      bind9-host
      bison
      bzip2-devel
      cloud-utils-growpart
      cmake
      cronie-anacron
      curl
      dhclient
      dnsutils
      e2fsprogs
      flex
      gdb
      gdisk
      glibc-static
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
      openssl
      openssl-devel
      parted
      psmisc
      quota
      readline-devel
      rpm-build
      rpmdevtools
      rsync
      rsyslog
      rsyslog-relp
      rsyslog-gnutls
      rsyslog-mmjsonparse
      runit
      strace
      sudo
      sysstat
      systemd
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
  end

  context 'installed by system_grub' do
    describe package('grub2-tools') do
      it { should be_installed }
    end
  end

  context 'ensure sendmail is removed (stig: V-38671)' do
    describe command('rpm -q sendmail') do
      its (:stdout) { should match ('package sendmail is not installed')}
    end
  end
end
