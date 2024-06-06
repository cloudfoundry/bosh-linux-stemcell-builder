require 'spec_helper'

describe 'CloudStack Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should match('cloudstack') }
    end
  end


  context 'installed by base_ssh' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end
end
