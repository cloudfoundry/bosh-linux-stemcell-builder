require 'spec_helper'

describe 'openSUSE leap stemcell', stemcell_image: true do

  it_behaves_like 'All Stemcells'
  it_behaves_like 'a openSUSE stemcell'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      its(:content) { should match('opensuse') }
    end
  end

  context 'installed by bosh_aws_agent_settings', {
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

  describe 'mounted file systems: /etc/fstab should mount nfs with nodev (stig: V-38654)(stig: V-38652)' do
    describe file('/etc/fstab') do
      it { should be_file }
      its(:content) { should_not match /nfs/ }
    end
  end
end
