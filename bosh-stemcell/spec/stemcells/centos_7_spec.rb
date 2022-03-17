require 'spec_helper'

describe 'CentOS 7 stemcell', stemcell_image: true do
  it_behaves_like 'All Stemcells'
  it_behaves_like 'a CentOS or RHEL stemcell'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it('identifies its OS as centos') { expect(subject.content).to match /centos/ }
    end
  end

  context 'installed by image_vsphere_cdrom stage', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_azure: true,
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

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it('enables CreatePartitionIfNoEphemeralDisk') do
        expect(subject.content).to match /"CreatePartitionIfNoEphemeralDisk": true/
      end
      it('has ConfigDrive') { expect(subject.content).to match /"Type": "ConfigDrive"/ }
      it('has HTTP') { expect(subject.content).to match /"Type": "HTTP"/ }
    end
  end

  context 'installed by dev_tools_config' do
    describe file('/var/vcap/bosh/etc/dev_tools_file_list') do
      it('has GCC installed') { expect(subject.content).to match '/usr/bin/gcc' }
    end
  end

  describe 'mounted file systems: /etc/fstab should mount nfs with nodev (stig: V-38654)(stig: V-38652)' do
    describe file('/etc/fstab') do
      it { should be_file }
      its (:content) { should_not match /nfs/ }
    end
  end

  describe 'installed packages' do
    rpm_list_packages = 'rpm --query --all --queryformat="%{NAME}\n"'

    let(:rpm_list_centos) { File.readlines(spec_asset('rpm-list-centos-7.txt')).map(&:chop) }
    let(:rpm_list_google_centos) { File.readlines(spec_asset('rpm-list-centos-7-google-additions.txt')).map(&:chop) }
    let(:rpm_list_vsphere_centos) { File.readlines(spec_asset('rpm-list-centos-7-vsphere-additions.txt')).map(&:chop) }
    let(:rpm_list_azure_centos) { File.readlines(spec_asset('rpm-list-centos-7-azure-additions.txt')).map(&:chop) }

    describe command(rpm_list_packages), {
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_azure: true,
    } do
      it 'contains only the base set of packages for aws, openstack, warden' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_centos)
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus google-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_centos.concat(rpm_list_google_centos))
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus vsphere-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_centos.concat(rpm_list_vsphere_centos))
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus azure-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_centos.concat(rpm_list_azure_centos))
      end
    end
  end

end

describe 'CentOS 7 stemcell tarball', stemcell_tarball: true do
  context 'installed by bosh_rpm_list stage' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/stemcell/packages.txt", no_chroot) do
      it { should be_file }
    end
  end

  context 'installed by dev_tools_config stage' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/stemcell/dev_tools_file_list.txt", no_chroot) do
      it { should be_file }
    end
  end
end
