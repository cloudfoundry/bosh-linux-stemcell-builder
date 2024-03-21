require 'spec_helper'

describe 'FIPS Stemcell', os_image: true do
  use_iaas_kernel = ENV.fetch('UBUNTU_FIPS_USE_IAAS_KERNEL', 'false') != 'true'
  context 'installed by system_kernel' do
    infrastructure = ENV['STEMCELL_INFRASTRUCTURE']
    describe package(use_iaas_kernel ? "linux-image-#{infrastructure}-fips" : "linux-image-fips") do
      it { should be_installed }
    end
    describe package('linux-generic') do
      it { should_not be_installed }
    end
    describe package('linux-image-5.19.0-109-generic') do
      it { should_not be_installed }
    end
  end

  context 'installed by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'allows only secure HMACs' do
      macs = %w[
          hmac-sha2-512-etm@openssh.com
          hmac-sha2-256-etm@openssh.com
          hmac-sha2-512
          hmac-sha2-256
      ].join(',')
      expect(sshd_config.content).to match(/^MACs #{macs}$/)
    end

    it 'enables RSA, ECDSA host keys' do
      matches = sshd_config.content.scan(/^HostKey.*/)

      expect(matches).to contain_exactly('HostKey /etc/ssh/ssh_host_rsa_key', 'HostKey /etc/ssh/ssh_host_ecdsa_key')
    end
  end

  context 'installed by image_install_grub for fips kernel' do
    describe file('/boot/grub/grub.cfg') do
      it { should be_file }
      its(:content) { should match %r{linux\t/boot/vmlinuz-\S+-fips root=UUID=\S* ro } }
      if use_iaas_kernel
        its(:content) { should match %r{initrd\t/boot/microcode.cpio /boot/initrd.img-\S+-fips} }
      else
        its(:content) { should match %r{initrd\t/boot/initrd.img-\S+-fips} }
      end
    end
  end

  linux_version_regex = 's/linux-(.+)-([0-9]+).([0-9]+).([0-9]+)-([0-9]+)/linux-\1-\2.\3/'

  describe 'installed packages' do
    dpkg_list_packages = "dpkg --get-selections | cut -f1 | sed -E '#{linux_version_regex}'"
    # TODO: maby we can use awk "dpkg --get-selections | awk '!/linux-(.+)-([0-9]+.+)/&&/linux/{print $1}'"

    let(:dpkg_list_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy.txt')).map(&:chop) }
    let(:dpkg_list_fips_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-fips.txt')).map(&:chop) }
    let(:dpkg_list_aws_fips_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-aws-fips.txt')).map(&:chop) }
    let(:dpkg_list_google_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-google-additions.txt')).map(&:chop) }
    let(:dpkg_list_vsphere_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-vsphere-additions.txt')).map(&:chop) }
    let(:dpkg_list_azure_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-azure-additions.txt')).map(&:chop) }
    let(:dpkg_list_cloudstack_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-cloudstack-additions.txt')).map(&:chop) }
    let(:dpkg_list_softlayer_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-jammy-softlayer-additions.txt')).map(&:chop) }
    let(:infrastructure) { ENV['STEMCELL_INFRASTRUCTURE'] }

    describe command(dpkg_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_cloudstack: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
      exclude_on_softlayer: true,
    } do
      it 'contains only the base set of packages plus aws-specific kernel packages' do
        skip "Test skipped due to generic kernel" unless use_iaas_kernel
        pkg_list = dpkg_list_ubuntu.concat(dpkg_list_aws_fips_ubuntu)
        pkg_list.delete('linux-firmware')
        pkg_list.delete('wireless-regdb')
        expect(subject.stdout.split("\n")).to match_array(pkg_list)
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_azure: true,
      exclude_on_softlayer: true,
    } do
      it 'contains only the base set of packages for alicloud, aws, openstack, warden' do
        skip "Test skipped due to IAAS-specific kernel" if use_iaas_kernel
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_fips_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
      exclude_on_softlayer: true,
    } do
      it 'contains only the base set of packages plus google-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_fips_ubuntu, dpkg_list_google_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
      exclude_on_softlayer: true,
    } do
      it 'contains only the base set of packages plus vsphere-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_fips_ubuntu, dpkg_list_vsphere_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
      exclude_on_softlayer: true,
    } do
      it 'contains only the base set of packages plus azure-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_fips_ubuntu, dpkg_list_azure_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus cloudstack-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_fips_ubuntu, dpkg_list_cloudstack_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus softlayer-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_fips_ubuntu, dpkg_list_softlayer_ubuntu))
      end
    end
  end
end
