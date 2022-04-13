shared_examples_for 'a CentOS or RHEL based OS image' do

  context 'Linux kernel modules' do
    context '/lib/modules' do
      describe command('ls -1 /lib/modules | wc -l') do
        before do
          skip 'inapplicable to RHEL 8: the RHEL 8.5 kernel RPM installs 2 kernel dirs at "/lib/modules/<KERNEL_VERSION>"' if ENV['OS_NAME'] == 'rhel' && ENV['OS_VERSION'] == '8'
        end

        it('should match only 1 kernel dir') { expect(subject.stdout).to eq "1\n" }
      end
    end
  end

  describe package('apt') do
    it { should_not be_installed }
  end

  describe package('rpm') do
    it { should be_installed }
  end

  describe user('vcap') do
    it { should be_in_group 'admin' }
    it { should be_in_group 'adm' }
    it { should be_in_group 'audio' }
    it { should be_in_group 'cdrom' }
    it { should be_in_group 'dialout' }
    it { should be_in_group 'floppy' }
    it { should be_in_group 'video' }
  end

  context 'installed by base_centos or base_rhel' do
    describe file('/etc/redhat-release') do
      it { should be_file }
    end

    describe file('/etc/lsb-release') do
      # NOTE: The stemcell builder automation infers the OS-type based on the existence of specific `/etc/*-release` files,
      # so this file MUST NOT exist in this stemcell,
      # or else the automation will incorrectly identify this stemcell as an Ubuntu stemcell.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      it { should_not be_file }
    end

    describe file('/etc/sysconfig/network') do
      it { should be_file }
    end

    context 'locale is set to US english, UTF8 charset' do
      describe file('/etc/locale.conf') do
        it { should be_file }
        its(:content) { should include 'en_US.UTF-8' }
      end
    end

    describe file('/etc/localtime') do
      it { should be_file }
      it { expect(subject.content.scrub).to match 'UTC' }
    end

    describe file('/usr/lib/systemd/system/runit.service') do
      it { should be_file }
      its(:content) { should match 'Restart=always' }
      its(:content) { should match 'KillMode=process' }
    end

    describe service('NetworkManager') do
      it { should be_enabled }
    end
  end

  context 'installed by base_runsvdir' do
    describe file('/var/run') do
      it { should be_linked_to('/run') }
    end
  end

  context 'installed or excluded by base_centos_packages' do
    %w(
      firewalld
      mlocate
      rpcbind
    ).each do |pkg|
      describe package(pkg) do
        it { should_not be_installed }
      end
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
      ).join(',')
      expect(sshd_config.content).to match(/^MACs #{macs}$/)
    end
  end

  context 'readahead-collector should be disabled' do
    describe file('/etc/sysconfig/readahead') do
      it { should be_file }
      its(:content) { should match 'READAHEAD_COLLECT="no"' }
      its(:content) { should match 'READAHEAD_COLLECT_ON_RPM="no"' }
    end
  end

  context 'installed by system_grub' do
    describe package('grub2-tools') do
      it { should be_installed, -> { "Message: #{subject.last_message} #{subject.last_error}" } }
    end
  end

  context 'configured by cron_config' do
    describe file '/etc/cron.daily/man-db.cron' do
      it { should_not be_file }
    end
  end

  context 'ensure cron is installed and enabled (stig: V-38605)' do
    # SEE: https://www.stigviewer.com/stig/red_hat_enterprise_linux_6/2018-11-28/finding/V-38605
    describe package('cronie') do
      it('should be installed') { should be_installed }
    end

    describe command('systemctl get-default') do
      its (:stdout) { should eq "multi-user.target\n" }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/crond.service') do
      it { should be_file }
      its(:content) { should match /^ExecStart=\/usr\/sbin\/crond/ }
    end
  end

  context 'configured by bosh_audit_centos' do
    context 'ensure auditd is installed (stig: V-38628) (stig: V-38631) (stig: V-38632)' do
      describe package('audit') do
        it { should be_installed }
      end
    end

    context 'ensure audit package file have unmodified contents (stig: V-38637)' do
      # ignore auditd.conf, and audit.rules since we modify these files in
      # other stigs
      describe command("rpm -V audit | grep -v 'auditd.conf' | grep -v 'audit.rules' | grep -v 'syslog.conf' | grep '^..5'") do
        its (:stdout) { should be_empty }
      end
    end

    describe file('/etc/audit/rules.d/audit.rules') do
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/lib64\/dbus-1\/dbus-daemon-launch-helper -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/openssh\/ssh-keysign -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/krb5_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/ldap_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/p11_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/proxy_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/sssd\/selinux_child -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/libexec\/utempter\/utempter -k privileged/ }
    end
  end

  context 'package signature verification (stig: V-38462) (stig: V-38483)' do
    describe command('grep nosignature /etc/rpmrc /usr/lib/rpm/rpmrc /usr/lib/rpm/redhat/rpmrc ~root/.rpmrc') do
      its (:stdout) { should_not include('nosignature') }
    end

    context 'gpgcheck must be enabled (stig: V-38483)' do
      describe file('/etc/yum.conf') do
        # NOTE: The original expectation doesn't ensure the stig V-38483 requirements are satisfied.
        # E.g. The original expectation could match a string outside of the '[main]' section.
        # Also, since the Fedora/RHEL default behavior is `gpgcheck=1`, a repo WITHOUT any explicit gpgcheck
        # config SHOULD satisfy this STIG's requirements.
        # its(:content) { should match /^gpgcheck=1$/ }

        # The following expectation SHOULD be completely effective IF RHEL's default behavior is `gpgcheck=1`
        # (which it seems to be), AND IF there is no way to override that default from outside this file.
        # see: https://docs.fedoraproject.org/en-US/quick-docs/fedora-and-red-hat-enterprise-linux/
        #   > RHEL 8 is based on Fedora v28
        # see: https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/package-management/DNF/#sec-Setting_main_Options
        # see: https://docs.fedoraproject.org/en-US/fedora/f28/system-administrators-guide/package-management/DNF/#sec-Setting_main_Options
        #   > In Fedora v28 & v35, `gpgcheck=1` is still the default
        # see: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/deployment_guide/sec-configuring_yum_and_yum_repositories
        #   > In RHEL 6, `gpgcheck=1` is still the default
        # see: https://docs.fedoraproject.org/en-US/Fedora/26/html/System_Administrators_Guide/sec-Configuring_DNF_and_DNF_Repositories.html#sec-Setting_main_Options
        #   > In Fedora v26, `gpgcheck=1` is the default
        its(:content) { should_not match /^gpgcheck=0$/ }
      end
    end
  end

  context 'X Windows must not be enabled unless required (stig: V-38674) (stig: V-230553)' do
    # SEE: https://www.stigviewer.com/stig/red_hat_enterprise_linux_8/2021-12-03/finding/V-230553
    # SEE: https://www.stigviewer.com/stig/red_hat_enterprise_linux_6/2016-06-05/finding/V-38674
    # NOTE: inittab is no longer used when using systemd (since RHEL 7.0), so STIG V-38674's original check & fix commands are obsolete.
    describe package('xorg-x11-server-Xorg') do
      it { should_not be_installed } # stig: V-38674, V-230553
    end

    describe package('xorg-x11-server-common') do
      it { should_not be_installed } # stig: V-38674, V-230553
    end

    describe package('xorg-x11-server-utils') do
      before do
        # NOTE: STIG V-230553's original check & fix commands consider the existence of the 'xorg-x11-server-utils' RPM package as a finding.
        # See the STIG V-230553 comments within 'stemcell_builder/stages/base_rhel/apply.sh' for details.
        skip 'inapplicable to RHEL 8: the "xorg-x11-server-utils" RPM package is a false positive finding' if ENV['OS_NAME'] == 'rhel' && ENV['OS_VERSION'] == '8'
      end

      it { should_not be_installed } # stig: V-38674, V-230553
    end

    describe package('xorg-x11-server-Xwayland') do
      it { should_not be_installed } # stig: V-38674, V-230553
    end
  end

  context 'graphical display manager must not be installed on RHEL 8 unless approved (stig: V-230553) (stig: V-38674)' do
    describe command('rpm -qa | grep xorg | grep server') do
      before do
        # NOTE: STIG V-230553's original check & fix commands consider the existence of the 'xorg-x11-server-utils' RPM package as a finding.
        # See the STIG V-230553 comments within 'stemcell_builder/stages/base_rhel/apply.sh' for details.
        skip 'inapplicable to RHEL 8: the "xorg-x11-server-utils" RPM package is a false positive finding' if ENV['OS_NAME'] == 'rhel' && ENV['OS_VERSION'] == '8'
      end

      its (:stdout) { should be_empty } # stig: V-230553
    end
  end

  context 'system is configured to boot to the command line (stig: V-251718)' do
    # graphical display manager must not be the default target (stig: V-251718)
    # SEE: https://www.stigviewer.com/stig/red_hat_enterprise_linux_8/2021-12-03/finding/V-251718
    describe command('systemctl get-default') do
      its (:stdout) { should eq "multi-user.target\n" }
    end
  end

  context 'login and password restrictions' do
    describe file('/etc/pam.d/system-auth') do
      it 'must prohibit the reuse of passwords within twenty-four iterations (stig: V-38658)' do
        expect(subject.content).to match /password.*pam_unix\.so.*remember=24/
      end

      it 'must prohibit new passwords shorter than 14 characters (stig: V-38475)' do
        expect(subject.content).to match /password.*pam_unix\.so.*minlen=14/
      end

      it 'must use the cracklib library to set correct password requirements (CIS-9.2.1)' do
        expect(subject.content).to match /password.*pam_cracklib\.so.*retry=3.*minlen=14.*dcredit=-1.*ucredit=-1.*ocredit=-1.*lcredit=-1/
      end

      it 'must restrict a user account after 5 failed login attempts (stig: V-38573 V-38501)' do
        expect(subject.content).to match /auth.*pam_unix.so.*\nauth.*default=die.*pam_faillock\.so.*authfail.*deny=5.*fail_interval=900\nauth\s*sufficient\s*pam_faillock\.so.*authsucc.*deny=5.*fail_interval=900/
      end
    end

    describe file('/etc/pam.d/password-auth') do
      it 'must restrict a user account after 5 failed login attempts (stig: V-38573 V-38501)' do
        expect(subject.content).to match /auth.*pam_unix.so.*\nauth.*default=die.*pam_faillock\.so.*authfail.*deny=5.*fail_interval=900\nauth\s*sufficient\s*pam_faillock\.so.*authsucc.*deny=5.*fail_interval=900/
      end
    end
  end

  context 'ctrl-alt-del restrictions' do
    context 'overriding control alt delete (stig: V-38668)' do
      describe file('/etc/systemd/system/ctrl-alt-del.target') do
        it { should be_file }
        it('remarks on the escaping') { expect(subject.content).to match '# escaping ctrl alt del' }
      end
    end
  end

  context 'ensure sendmail is removed (stig: V-38671)' do
    describe command('rpm -q sendmail') do
      its (:stdout) { should include ('package sendmail is not installed')}
    end
  end

  context 'ensure xinetd is not installed nor enabled (stig: V-38582)' do
    describe package('xinetd') do
      it('should not be installed') { should_not be_installed }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/xinetd.service') do
      it { should_not be_file }
    end
  end

  context 'ensure ypbind is not installed nor enabled (stig: V-38604)' do
    describe package('ypbind') do
      it('should not be installed') { should_not be_installed }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/ypbind.service') do
      it { should_not be_file }
    end
  end

  context 'ensure ypserv is not installed (stig: V-38603)' do
    describe package('ypserv') do
      it('should not be installed') { should_not be_installed }
    end
  end

  context 'PAM configuration' do
    describe file('/usr/lib64/security/pam_cracklib.so') do
      it { should be_file }
    end
  end

  context 'display the number of unsuccessful logon/access attempts since the last successful logon/access (stig: V-51875)' do
    describe file('/etc/pam.d/system-auth') do
      its(:content){ should match /session     required      pam_lastlog\.so showfailed/ }
    end
  end

  context 'installed by bosh_sysctl' do
    describe file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      it { should be_file }

      it 'must limit the ability of processes to have simultaneous write and execute access to memory. (only centos) (stig: V-38597)' do
        expect(subject.content).to match /^kernel.exec-shield=1$/
      end
    end
  end

  context 'ensure net-snmp is not installed (stig: V-38660) (stig: V-38653)' do
    describe package('net-snmp') do
      it { should_not be_installed }
    end
  end

  context 'Ensure NFS and RPC are not enabled (CIS-6.7)' do
    # SEE: section 6.7 of: https://security.uri.edu/files/CIS_Ubuntu_14.04_LTS_Server_Benchmark_v1.0.0.pdf
    # SEE: https://blackhole.nmrc.org/code-testing/sast-testing/-/blob/master/wazuh-master/ruleset/sca/debian/cis_debian7.yml#L818-833

    context 'ensure rpcbind is not enabled (CIS-6.7)' do
      describe file('/etc/init/rpcbind-boot.conf') do
        it { should_not be_file }
      end

      describe file('/etc/init/rpcbind.conf') do
        it { should_not be_file }
      end
    end

    context 'ensure nfs is not enabled (CIS-6.7)' do
      describe command("ls /etc/rc*.d/ | grep S*nfs-kernel-server") do
        its (:stdout) { should be_empty }
      end
    end
  end

  context 'restrict access to the su command CIS-9.5' do
    # SEE: https://access.redhat.com/solutions/64860
    describe command('grep "^\s*auth\s*required\s*pam_wheel.so\s*use_uid" /etc/pam.d/su') do
      it('exits 0') { expect(subject.exit_status).to eq(0) }
      it('exits 0') { expect(subject.exit_status).to eq(0), -> { "Stdout: #{subject.stdout} Stderr: #{subject.stderr}" } }
    end
    describe file('/etc/pam.d/su') do
      it { should be_file }
      its (:content) { should match(/^\s*auth\s*required\s*pam_wheel.so\s*use_uid/) }
      it('has expected auth config') { expect(subject.content).to match(/^\s*auth\s*required\s*pam_wheel.so\s*use_uid/), -> { "content: #{subject.content}" } }
    end
    describe user('vcap') do
      it { should exist }
      it { should be_in_group 'wheel' }
    end
  end

  describe 'logging and audit startup script' do
    describe file('/var/vcap/bosh/bin/bosh-start-logging-and-auditing') do
      it { should be_file }
      it { should be_executable }
      it('starts auditd') { expect(subject.content).to match('service auditd start') }
    end
  end
end
