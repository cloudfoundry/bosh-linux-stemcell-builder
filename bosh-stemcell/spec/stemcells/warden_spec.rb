require 'spec_helper'

describe 'Warden Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('warden') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should_not match /^PasswordAuthentication no$/ }
      its(:content) { should match /^PasswordAuthentication yes$/ }
    end
  end
end
