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
      its(:content) { should include('"UserDataPath": "/var/lib/waagent/CustomData"') }
      its(:content) { should include('"SettingsPath": "/var/lib/waagent/CustomData"') }
      its(:content) { should include('"UseServerName": true') }
      its(:content) { should include('"UseRegistry": true') }
      its(:content) { should include('"DevicePathResolutionType": "scsi"') }
      its(:content) { should include('"CreatePartitionIfNoEphemeralDisk": true') }
      its(:content) { should include('"PartitionerType": "parted"') }
    end
  end
end
