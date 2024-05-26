require 'spec_helper'

describe 'OpenStack Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('openstack') }
    end
  end

  context 'installed by package_qcow2_image stage' do
    describe 'converts to qcow2 0.10 compat' do
      # environment is cleaned up inside rspec context
      stemcell_image = ENV['STEMCELL_IMAGE']

      subject do
        cmd = "qemu-img info #{File.join(File.dirname(stemcell_image), 'root.qcow2')}"
        `#{cmd}`
      end

      it { should include("compat: 0.10") }
    end
  end

  context 'installed by base_ssh' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end
end
