require 'spec_helper'

describe 'Ubuntu 14.04 stemcell image', stemcell_image: true do
  it_behaves_like 'All Stemcells'

  context 'installed by image_install_grub', {exclude_on_ppc64le: true} do
    describe file('/boot/grub/grub.conf') do
      it { should be_file }
      its(:content) { should match 'default=0' }
      its(:content) { should match 'timeout=1' }
      its(:content) { should match %r{^title Ubuntu 14\.04.* LTS \(.*\)$} }
      its(:content) { should match /^  root \(hd0,0\)$/ }
      its(:content) { should match %r{kernel /boot/vmlinuz-\S+-generic ro root=UUID=} }
      its(:content) { should match ' selinux=0' }
      its(:content) { should match ' cgroup_enable=memory swapaccount=1' }
      its(:content) { should match ' console=ttyS0,115200n8 console=tty0' }
      its(:content) { should match ' earlyprintk=ttyS0 rootdelay=300' }
      its(:content) { should match %r{initrd /boot/initrd.img-\S+-generic} }

      it('should set the grub menu password (stig: V-38585)') { expect(subject.content).to match /^password --md5 \*/ }
      it('should be of mode 600 (stig: V-38583)') { expect(subject).to be_mode(0600) }
      it('should be owned by root (stig: V-38579)') { expect(subject).to be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { expect(subject.group).to eq('root') }
      it('audits processes that start prior to auditd (CIS-8.1.3)') { expect(subject.content).to match ' audit=1' }
    end

    describe file('/boot/grub/menu.lst') do
      before { skip 'until aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.conf') }
    end
  end

  context 'installs recent version of unshare so it gets the -p flag', {
    exclude_on_aws: true,
    exclude_on_azure: true,
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
        found_libraries = command('find / -iname "*.a" | sort | uniq').stdout.split("\n")

        expect(libraries_to_remove).to include(*found_libraries)
      end
    end
  end

  context 'modified by base_file_permissions' do
    describe 'disallow unsafe setuid binaries' do
      subject { command('find -L / -xdev -perm /ug=s -type f') }

      it('includes the correct binaries') { expect(subject.stdout.split).to match_array(%w(/bin/su /usr/bin/sudo /usr/bin/sudoedit)) }
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
    exclude_on_aws: true,
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
    exclude_on_aws: true,
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
  end

  context 'installed by system_softlayer_open_iscsi', {
      exclude_on_aws: true,
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
      exclude_on_aws: true,
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

  context 'installed by image_vsphere_cdrom stage', {
    exclude_on_aws: true,
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

  context 'installed by bosh_aws_agent_settings', {
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
    exclude_on_aws: true,
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
    exclude_on_aws: true,
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
    exclude_on_aws: true,
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
      exclude_on_aws: true,
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should match('"Type": "File"') }
      its(:content) { should match('"SettingsPath": "/var/vcap/bosh/user_data.json"') }
      its(:content) { should match('"UseRegistry": true') }
    end
  end

  describe 'mounted file systems: /etc/fstab should mount nfs with nodev (stig: V-38654) (stig: V-38652)' do
    describe file('/etc/fstab') do
      it { should be_file }
      its (:content) { should eq("# UNCONFIGURED FSTAB FOR BASE SYSTEM\n") }
    end
  end

  describe 'installed packages' do
    dpkg_list_packages = "dpkg --get-selections | cut -f1 | sed -E 's/(linux.*4.4).*/\\1/'"

    let(:dpkg_list_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-trusty.txt')).map(&:chop) }
    let(:dpkg_list_google_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-trusty-google-additions.txt')).map(&:chop) }
    let(:dpkg_list_vsphere_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-trusty-vsphere-additions.txt')).map(&:chop) }
    let(:dpkg_list_azure_ubuntu) { File.readlines(spec_asset('dpkg-list-ubuntu-trusty-azure-additions.txt')).map(&:chop) }

    describe command(dpkg_list_packages), {
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_azure: true,
    } do
      it 'contains only the base set of packages for aws, openstack, warden' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu)
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus google-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_google_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_aws: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus vsphere-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_vsphere_ubuntu))
      end
    end

    describe command(dpkg_list_packages), {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus azure-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(dpkg_list_ubuntu.concat(dpkg_list_azure_ubuntu))
      end
    end
  end
end

describe 'Ubuntu 14.04 stemcell tarball', stemcell_tarball: true do
  context 'installed by bosh_dpkg_list stage' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/stemcell/packages.txt", ShelloutTypes::Chroot.new('/')) do
      it { should be_file }
      its(:content) { should match 'Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend' }
      its(:content) { should match 'ubuntu-minimal' }
    end
  end

  context 'installed by dev_tools_config stage' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/stemcell/dev_tools_file_list.txt", ShelloutTypes::Chroot.new('/')) do
      it { should be_file }
    end
  end
end
