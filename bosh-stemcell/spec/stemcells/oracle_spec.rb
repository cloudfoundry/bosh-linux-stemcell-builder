require 'spec_helper'

describe 'Oracle Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('oracle') }
    end
  end

  context 'installed by package_qcow2_image stage' do
    describe 'converts to qcow2 0.10(x86) or 1.1(ppc64le) compat' do
      # environment is cleaned up inside rspec context
      stemcell_image = ENV['STEMCELL_IMAGE']

      subject do
        cmd = "qemu-img info #{File.join(File.dirname(stemcell_image), 'root.qcow2')}"
        `#{cmd}`
      end

      it {
        compat = Bosh::Stemcell::Arch.ppc64le? ? '1.1' : '0.10'
        should include("compat: #{compat}")
      }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      its(:content) { should match /^PasswordAuthentication no$/ }
    end
  end

  context 'installed by image_install_grub' do
    describe file('/boot/grub/grub.cfg') do
      it { should be_file }
      its(:content) { should match 'default="0"' }
      its(:content) { should match 'timeout=1' }
#      its(:content) { should match %r{linux\s+/boot/vmlinuz-\S+-generic root=UUID=\S+\s+ro} }
      its(:content) { should match ' selinux=0' }
      its(:content) { should match ' ipv6\.disable=1 ' }
      its(:content) { should match ' cgroup_enable=memory swapaccount=1' }
      its(:content) { should match ' console=ttyS0,115200n8 console=tty0' }
      its(:content) { should match ' earlyprintk=ttyS0 rootdelay=300' }
      its(:content) { should match %r{initrd\t/boot/initrd.img-\S+-generic} }

      it('should set the grub menu password (stig: V-38585)') { expect(subject.content).to match /^password_pbkdf2 vcap grub.pbkdf2.sha512.10000.*/ }
      it('should be of mode 600 (stig: V-38583)') { expect(subject).to be_mode(0600) }
      it('should be owned by root (stig: V-38579)') { expect(subject).to be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { expect(subject.group).to eq('root') }
      it('audits processes that start prior to auditd (CIS-8.1.3)') { expect(subject.content).to match ' audit=1' }
    end
  end

  context 'ipv6 is disabled in the kernel' do
    describe file('/boot/grub/grub.cfg') do
      its(:content) { should match /^\s+linux\t.*ipv6\.disable=1 .*$/}
    end
  end

end
