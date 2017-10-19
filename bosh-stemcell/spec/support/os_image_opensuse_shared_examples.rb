shared_examples_for 'a openSUSE based OS image' do

  describe command('ls -1 /lib/modules | wc -l') do
    its(:stdout) {should eq "1\n"}
  end

  describe package('apt') do
    it { should_not be_installed }
  end

  describe package('rpm') do
    it { should be_installed }
  end

  context 'installed by base_opensuse' do
    describe file('/etc/SuSE-release') do
      it { should be_file }
    end

    describe file('/etc/localtime') do
      it { expect(subject.content.scrub).to match 'UTC' }
    end

    describe file('/usr/lib/systemd/system/runit.service') do
      it { should be_file }
      its(:content) { should match 'Restart=always' }
    end

    describe command('systemctl is-enabled wicked') do
      its(:stdout) { should match /enabled/ }
    end
  end

  context 'installed by base_runsvdir' do
    describe file('/var/run') do
      it { should be_linked_to('/run') }
    end
  end

  context 'installed by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'only allow 3DES and AES series ciphers (stig: V-38617)' do
      ciphers = %w(
        aes256-ctr
        aes192-ctr
        aes128-ctr
      ).join(',')
      expect(sshd_config.content).to match(/^Ciphers #{ciphers}$/)
    end

    it 'allows only secure HMACs and the weaker SHA1 HMAC required by golang ssh lib' do
      macs = %w(
        hmac-sha2-512
        hmac-sha2-256
        hmac-ripemd160
        hmac-sha1
      ).join(',')
      expect(sshd_config.content).to match(/^MACs #{macs}$/)
    end
  end

  context 'configured by cron_config' do
    describe file '/etc/cron.daily/man-db.cron' do
      it { should_not be_file }
    end
  end

  context 'package signature verification (stig: V-38462)' do
    describe command('grep nosignature /etc/rpmrc /usr/lib/rpm/rpmrc /usr/lib/rpm/redhat/rpmrc ~root/.rpmrc') do
      its (:stdout) { should_not include('nosignature') }
    end
  end

  context 'X Windows must not be enabled unless required (stig: V-38674)' do
    describe package('xorg-x11-server-Xorg') do
      it { should_not be_installed }
    end
  end

  context 'login and password restrictions' do
    describe file('/etc/pam.d/common-password') do
      it 'must prohibit the reuse of passwords within twenty-four iterations (stig: V-38658)' do
        expect(subject.content).to match /password.*pam_unix\.so.*remember=24/
      end

      it 'must prohibit new passwords shorter than 14 characters (stig: V-38475)' do
        expect(subject.content).to match /password.*pam_unix\.so.*minlen=14/
      end

      it 'must use the cracklib library to set correct password requirements (CIS-9.2.1)' do
        expect(subject.content).to match /password.*pam_cracklib\.so.*retry=3.*minlen=14.*dcredit=-1.*ucredit=-1.*ocredit=-1.*lcredit=-1/
      end
    end

    describe file('/etc/pam.d/common-account') do
      it 'must reset the tally of a user after successful login, esp. `sudo` (stig: V-38573)' do
        expect(subject.content).to match(/account.*required.*pam_tally2\.so/)
      end
    end

    describe file('/etc/pam.d/common-auth') do
      it 'must restrict a user account after 5 failed login attempts (stig: V-38573)' do
        expect(subject.content).to match(/auth.*pam_tally2\.so.*deny=5/)
      end
    end
  end

  context 'restrict access to the su command CIS-9.5' do
    describe command('grep "^\s*auth\s*required\s*pam_wheel.so\s*use_uid" /etc/pam.d/su') do
      its(:exit_status) { should eq(0) }
    end
    describe user('vcap') do
      it { should exist }
      it { should be_in_group 'wheel' }
    end
  end
end
