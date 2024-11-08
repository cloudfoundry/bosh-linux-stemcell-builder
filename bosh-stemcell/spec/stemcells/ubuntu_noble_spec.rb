require 'spec_helper'

describe 'Ubuntu 24.04 stemcell image', stemcell_image: true do
  it_behaves_like 'All Stemcells'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  # linux_version_regex = '/linux-(.+)-([0-9]+.+)/d'
  linux_version_regex = 's/linux-(.+)-([0-9]+).([0-9]+).([0-9]+)-([0-9]+)/linux-\1-\2.\3/'

  context 'installed by image_install_grub', {
    exclude_on_softlayer: true,
    exclude_on_vsphere: true,
    exclude_on_google: true,
    exclude_on_aws: true,
  } do
    context 'for cloudstack infrastructure and xen hypervisor', {
        exclude_on_alicloud: true,
        exclude_on_vcloud: true,
        exclude_on_warden: true,
        exclude_on_azure: true,
        exclude_on_openstack: true,
    } do
      describe file(grub_cfg_path) do
        its(:content) { should match ' console=hvc0' }
      end
    end
    describe file(grub_cfg_path) do
      it { should be_file }
      its(:content) { should match 'set default="0"' }
      its(:content) { should match(/^set root=\(hd0,0\)$/) }
      its(:content) { should match ' selinux=0' }
      its(:content) { should match ' cgroup_enable=memory swapaccount=1' }
      its(:content) { should match ' console=ttyS0,115200n8' }
      its(:content) { should match ' earlyprintk=ttyS0 rootdelay=300' }

      it('should set the grub menu password (stig: V-38585)') { expect(subject.content).to match /password_pbkdf2 vcap/ }
      it('should be of mode 600 (stig: V-38583)') { expect(subject).to be_mode(0600) }
      it('should be owned by root (stig: V-38579)') { expect(subject).to be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { expect(subject.group).to eq('root') }
      it('audits processes that start prior to auditd (CIS-8.1.3)') { expect(subject.content).to match ' audit=1' }
    end

    context 'for default kernel', exclude_on_fips: true do
      describe file(grub_cfg_path) do
        it { should be_file }
        its(:content) { should match %r{linux\t/boot/vmlinuz-\S+-generic root=UUID=\S* ro } }
        its(:content) { should match %r{initrd\t/boot/initrd.img-\S+-generic} }
      end
    end

    describe file('/boot/grub/menu.lst') do
      before { skip 'until alicloud/aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.cfg') }
    end
  end

  context 'installed by image_install_grub', {
    exclude_on_softlayer: true,
    exclude_on_cloudstack: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_azure: true,
  } do
    describe file('/boot/efi/EFI/grub/grub.cfg') do
      it { should be_file }
      its(:content) { should match 'set default="0"' }
      its(:content) { should match ' selinux=0' }
      its(:content) { should match ' cgroup_enable=memory swapaccount=1' }
      its(:content) { should match ' console=ttyS0,115200n8' }
      its(:content) { should match ' earlyprintk=ttyS0 rootdelay=300' }

      it('should set the grub menu password (stig: V-38585)') { expect(subject.content).to match /password_pbkdf2 vcap/ }
      it('should be of mode 600 (stig: V-38583)') { expect(subject).to be_mode(0600) }
      it('should be owned by root (stig: V-38579)') { expect(subject).to be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { expect(subject.group).to eq('root') }
      it('audits processes that start prior to auditd (CIS-8.1.3)') { expect(subject.content).to match ' audit=1' }
    end

    context 'for default kernel', exclude_on_fips: true do
      describe file('/boot/efi/EFI/grub/grub.cfg') do
        it { should be_file }
        its(:content) { should match %r{linux\t/boot/vmlinuz-\S+-generic root=UUID=\S* ro } }
        its(:content) { should match %r{initrd\t/boot/initrd.img-\S+-generic} }
      end
    end

    describe file('/boot/grub/menu.lst') do
      before { skip 'until alicloud/aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.cfg') }
    end
  end

  context 'installed by image_install_grub_softlayer_two_partitions', {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vsphere: true,
      exclude_on_vcloud: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
      exclude_on_azure: true,
  } do
    describe file(grub_cfg_path) do
      it { should be_file }
      its(:content) { should match 'set default="0"' }
      its(:content) { should match(/^set root=\(hd0,2\)$/) }
      its(:content) { should match %r{linux\t/vmlinuz-\S+-generic root=UUID=\S* ro } }
      its(:content) { should match ' selinux=0' }
      its(:content) { should match ' cgroup_enable=memory swapaccount=1' }
      its(:content) { should match ' console=ttyS0,115200n8' }
      its(:content) { should match ' earlyprintk=ttyS0 rootdelay=300' }
      its(:content) { should match %r{initrd\t/initrd.img-\S+-generic} }

      it('should set the grub menu password (stig: V-38585)') { expect(subject.content).to match /password_pbkdf2 vcap/ }
      it('should be of mode 600 (stig: V-38583)') { expect(subject).to be_mode(0600) }
      it('should be owned by root (stig: V-38579)') { expect(subject).to be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { expect(subject.group).to eq('root') }
      it('audits processes that start prior to auditd (CIS-8.1.3)') { expect(subject.content).to match ' audit=1' }
    end

    describe file('/boot/grub/menu.lst') do
      before { skip 'until alicloud/aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.cfg') }
    end
  end

  context 'installs recent version of unshare so it gets the -p flag', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_azure: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_openstack: true,
    exclude_on_softlayer: true,
  } do
    context 'so we can run upstart in as PID 1 in the container' do
      describe file('/var/vcap/bosh/bin/unshare') do
        it { should be_file }
        it { should be_executable }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      its(:content) { should match('ubuntu') }
    end
  end

  context 'installed by dev_tools_config' do
    describe file('/var/vcap/bosh/etc/dev_tools_file_list') do
      its(:content) { should match('/usr/bin/gcc') }
    end
  end

  context 'static libraries to remove' do
    describe file('/var/vcap/bosh/etc/static_libraries_list') do
      it { should be_file }

      it 'should be a proper superset of the installed static libraries' do
        libraries_to_remove = subject.content.split("\n")
        found_libraries = command('find / -iname "*.a" | sort | uniq' ).stdout.split("\n")

        expect(libraries_to_remove).to include(*found_libraries)
      end
    end
  end

  context 'modified by base_file_permissions' do
    describe 'disallow unsafe setuid binaries' do
      subject { command('find -L / -xdev -perm /ug=s -type f') }

      it ('includes the correct binaries') do
        # expect(subject.stdout.split).to match_array(%w(/bin/su /usr/bin/sudo /usr/bin/sudoedit))
        expect(subject.stdout.split).to match_array(%w(/bin/su /bin/sudo /bin/sudoedit /usr/bin/su /usr/bin/sudo /usr/bin/sudoedit))

      end
    end
  end

  context 'installed by system-network', {
    exclude_on_warden: true
  } do
    describe file('/etc/hostname') do
      it { should be_file }
      its (:content) { should eq('bosh-stemcell') }
    end
  end

  context 'installed by system-network on some IaaSes', {
    exclude_on_vsphere: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/etc/network/interfaces') do
      it { should be_file }
      its(:content) { should match 'auto lo' }
      its(:content) { should match 'iface lo inet loopback' }
    end
  end

  context 'installed by system-azure-network', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_softlayer: true,
  } do
    describe file('/etc/network/interfaces') do
      it { should be_file }
      its(:content) { should match 'auto eth0' }
      its(:content) { should match 'iface eth0 inet dhcp' }
    end
  end

  context 'installed by system_open_vm_tools', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe package('open-vm-tools') do
      it { should be_installed }
    end
    describe file('/etc/vmware-tools/tools.conf') do
      it { should be_file }
      its(:content) { should match '\[guestinfo\]' }
      its(:content) { should match 'exclude-nics=veth\*,docker\*,virbr\*,silk-vtep,s-\*,ovs\*,erspan\*,nsx-container,antrea\*,\?\?\?\?\?\?\?\?\?\?\?\?\?\?\?' }
    end
  end

  context 'installed by system_softlayer_open_iscsi', {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vsphere: true,
      exclude_on_vcloud: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
      exclude_on_azure: true,
  } do
    describe package('open-iscsi') do
      it { should be_installed }
    end
  end

  context 'installed by system_softlayer_multipath_tools', {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vsphere: true,
      exclude_on_vcloud: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
      exclude_on_azure: true,
  } do
    describe package('multipath-tools') do
      it { should be_installed }
    end
  end

  context 'installed by system_softlayer_netplan', {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vsphere: true,
      exclude_on_vcloud: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
      exclude_on_azure: true,
  } do
    describe package('netplan.io') do
      it { should be_installed }
    end
  end

  context 'installed by image_vsphere_cdrom stage', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/etc/udev/rules.d/60-cdrom_id.rules') do
      it { should be_file }
      its(:content) { should eql(<<HERE) }
# Generated by BOSH stemcell builder

ACTION=="remove", GOTO="cdrom_end"
SUBSYSTEM!="block", GOTO="cdrom_end"
KERNEL!="sr[0-9]*|xvd*", GOTO="cdrom_end"
ENV{DEVTYPE}!="disk", GOTO="cdrom_end"

# unconditionally tag device as CDROM
KERNEL=="sr[0-9]*", ENV{ID_CDROM}="1"

# media eject button pressed
ENV{DISK_EJECT_REQUEST}=="?*", RUN+="cdrom_id --eject-media $devnode", GOTO="cdrom_end"

# Do not lock CDROM drive when cdrom is inserted
# because vSphere will start asking questions via API.
# IMPORT{program}="cdrom_id --lock-media $devnode"
IMPORT{program}="cdrom_id $devnode"

KERNEL=="sr0", SYMLINK+="cdrom", OPTIONS+="link_priority=-100"

LABEL="cdrom_end"
HERE
    end
  end

  context 'installed by bosh-agent', {} do
    describe file('/lib/systemd/system/bosh-agent.service') do
      it { should be_file }
      its(:content) { should match 'Restart=always' }
      its(:content) { should match 'KillMode=process' }
    end
    describe service('bosh-agent') do
      it { should be_enabled }
    end
   end

  context 'installed by bosh_alicloud_agent_settings', {
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_openstack: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"Type": "HTTP"') }
    end
  end

  context 'installed by bosh_aws_agent_settings', {
    exclude_on_alicloud: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_openstack: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"Type": "HTTP"') }
    end
  end

  context 'installed by bosh_google_agent_settings', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_openstack: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"Type": "InstanceMetadata"') }
    end
  end

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"CreatePartitionIfNoEphemeralDisk": true') }
      its(:content) { should match('"Type": "ConfigDrive"') }
      its(:content) { should match('"Type": "HTTP"') }
    end
  end

  context 'installed by bosh_vsphere_agent_settings', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_cloudstack: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_openstack: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"Type": "CDROM"') }
    end
  end

  context 'installed by bosh_softlayer_agent_settings', {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"Type": "HTTP"') }
      its(:content) { should match('"UserDataPath": "/rest/v3.1/SoftLayer_Resource_Metadata/getUserMetadata.json"') }
      its(:content) { should match('"UseRegistry": true') }
    end
  end

  context 'installed by bosh_cloudstack_agent_settings', {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
      exclude_on_google: true,
      exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"CreatePartitionIfNoEphemeralDisk": true') }
      its(:content) { should match('"Type": "HTTP"') }
    end
  end

  describe 'mounted file systems: /etc/fstab should mount nfs with nodev (stig: V-38654) (stig: V-38652)' do
    describe file('/etc/fstab') do
      it { should be_file }
      its (:content) { should_not match /nfs/ }
    end
  end

  context 'open ports' do
    context 'when nfs is removed' do
      describe command('lsof -iTCP:111') do
        its(:exit_status) { should eq(1) }
      end
    end
  end

  context 'installed by system_kernel', exclude_on_fips: true  do
    describe package('linux-generic') do
      it { should be_installed }
    end
  end

  describe 'installed packages' do
    dpkg_list_packages = "dpkg --get-selections | cut -f1 | sed -E '#{linux_version_regex}'"
    # TODO: maby we can use awk "dpkg --get-selections | awk '!/linux-(.+)-([0-9]+.+)/&&/linux/{print $1}'"

    let(:dpkg_list_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble.txt')).map(&:chop) }
    let(:dpkg_list_kernel_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble-kernel.txt')).map(&:chop) }
    let(:dpkg_list_google_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble-google-additions.txt')).map(&:chop) }
    let(:dpkg_list_vsphere_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble-vsphere-additions.txt')).map(&:chop) }
    let(:dpkg_list_azure_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble-azure-additions.txt')).map(&:chop) }
    let(:dpkg_list_cloudstack_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble-cloudstack-additions.txt')).map(&:chop) }
    let(:dpkg_list_softlayer_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-noble-softlayer-additions.txt')).map(&:chop) }

    describe command(dpkg_list_packages), {
      exclude_on_fips: true,
      exclude_on_cloudstack: true,
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_azure: true,
      exclude_on_softlayer: true,
    } do
      it 'contains only the base set of packages for alicloud, aws, openstack, warden' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_kernel_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_fips: true,
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
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_kernel_ubuntu, dpkg_list_google_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_fips: true,
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
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_kernel_ubuntu, dpkg_list_vsphere_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_fips: true,
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
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_kernel_ubuntu, dpkg_list_azure_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_fips: true,
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
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_kernel_ubuntu, dpkg_list_cloudstack_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_fips: true,
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
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_kernel_ubuntu, dpkg_list_softlayer_ubuntu))
      end
    end
  end
end

describe 'Ubuntu 24.04 stemcell tarball', stemcell_tarball: true do
  context 'installed by bosh_dpkg_list stage' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/stemcell/packages.txt", ShelloutTypes::Chroot.new('/')) do
      it { should be_file }
      its(:content) { should match 'Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend' }
    end
  end

  context 'installed by dev_tools_config stage' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/stemcell/dev_tools_file_list.txt", ShelloutTypes::Chroot.new('/')) do
      it { should be_file }
    end
  end
end
