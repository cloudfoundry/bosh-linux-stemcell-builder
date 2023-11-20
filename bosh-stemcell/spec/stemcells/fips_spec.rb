require 'spec_helper'

describe 'FIPS Stemcell', os_image: true do
  context 'installed by system_kernel' do
    describe package('linux-aws-fips') do
      it { should be_installed }
    end
    describe package('linux-generic-hwe-22.04') do
      it { should_not be_installed }
    end
    describe package('linux-image-5.19.0-109-generic') do
      it { should_not be_installed }
    end
  end

  context 'installed by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'allows only secure HMACs' do
      macs = %w[
          hmac-sha2-512-etm@openssh.com
          hmac-sha2-256-etm@openssh.com
          hmac-sha2-512
          hmac-sha2-256
      ].join(',')
      expect(sshd_config.content).to match(/^MACs #{macs}$/)
    end
  end
end
