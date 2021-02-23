require 'spec_helper'

describe 'AliCloud Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should match('alicloud') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end

  context 'ext4 filesystems' do
    describe 'should not contain ext4 feature metadata_csum' do
      subject { file('/etc/mke2fs.conf') }

      its(:content) { should_not match /metadata_csum/ }
    end
  end

  context 'default grub configuration' do
    describe file('/etc/default/grub') do
      it { should be_file }
      its(:content) { should match '^GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"' }
    end
  end

  context 'installed by image_install_grub' do
    describe file('/boot/grub/grub.cfg') do
      it { should be_file }
      its(:content) { should match ' ipv6.disable=1' }
    end
  end
end
