require 'spec_helper'

describe 'AWS Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should match('aws') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end

  describe 'nvme' do
    describe 'nvme-id finder' do
      subject { file('/sbin/nvme-id') }

      it { should be_file }
      it { should be_executable }
      its(:content) { should match(/nvme id-ctrl/) }
    end

    describe 'udev rules' do
      subject { file('/etc/udev/rules.d/70-ec2-nvme-devices.rules') }

      it { should be_file }
      its(:content) { should match %r{/sbin/nvme-id} }
    end
  end
end
