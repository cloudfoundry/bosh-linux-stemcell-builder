require 'spec_helper'

describe 'Azure Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('azure') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }
      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end

  context 'udf module should be enabled' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      its(:content) { should_not match 'install udf /bin/true' }
    end
  end

  context 'installed by bosh_azure_agent_settings', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should include('"Type": "File"') }
      its(:content) { should include('"MetaDataPath": ""') }
      its(:content) { should include('"UserDataPath": "/var/lib/cloud/instance/user-data.txt"') }
      its(:content) { should include('"SettingsPath": "/var/lib/cloud/instance/user-data.txt"') }
      its(:content) { should include('"UseServerName": true') }
      its(:content) { should include('"DevicePathResolutionType": "scsi"') }
      its(:content) { should include('"CreatePartitionIfNoEphemeralDisk": true') }
      its(:content) { should include('"PartitionerType": "parted"') }
    end
  end

  context 'installed by system_azure_network', {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_softlayer: true,
  } do
    describe 'SR-IOV VF udev rules' do
      subject { file('/etc/udev/rules.d/10-azure-sriov-unmanaged.rules') }

      it { should be_mode(644) }
      it { should be_owned_by('root') }

      its(:content) { should match /SUBSYSTEM=="net"/ }
      its(:content) { should match /ATTR\{flags\}=="0\?\?\[89ABCDEF\]\*"/ }
      its(:content) { should match /ENV\{AZURE_UNMANAGED_SRIOV\}="1"/ }
      its(:content) { should match /ENV\{ID_NET_MANAGED_BY\}="unmanaged"/ }
      its(:content) { should match /ENV\{NM_UNMANAGED\}="1"/ }
      its(:content) { should match /ATTR\{ifalias\}="sriov-vf"/ }
    end

    describe 'systemd network configuration for unmanaged SR-IOV devices' do
      subject { file('/etc/systemd/network/01-azure-sriov-unmanaged.network') }

      it { should be_mode(644) }
      it { should be_owned_by('root') }

      its(:content) { should match /\[Match\]/ }
      its(:content) { should match /Property=AZURE_UNMANAGED_SRIOV=1/ }
      its(:content) { should match /\[Link\]/ }
      its(:content) { should match /Unmanaged=yes/ }
    end
  end
end
