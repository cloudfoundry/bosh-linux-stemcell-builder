require 'spec_helper'

describe 'vCloud Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('vsphere') }
    end
  end

  describe 'ssh authentication' do
    describe 'allows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should_not match /^PasswordAuthentication no$/ }
      its(:content) { should match /^PasswordAuthentication yes$/ }
    end
  end
end
