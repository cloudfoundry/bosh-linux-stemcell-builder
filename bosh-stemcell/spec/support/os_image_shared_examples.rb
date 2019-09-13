shared_examples_for 'every OS image' do
  let(:sshd_config) { file('/etc/ssh/sshd_config') }
  let(:etc_environment) { file('/etc/environment') }

  context 'etc_environment' do
    it 'should have /var/vcap/bosh/bin on the PATH' do
      expect(etc_environment.content).to match(
        %r{PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/var/vcap/bosh/bin"},
      )
    end
  end

  context 'installed by base_<os>' do
    describe command('dig -v') do # required by agent
      it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
    end

    describe command('which crontab') do
      it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
    end
  end

  context 'installed by bosh_sudoers' do
    describe file('/etc/sudoers') do
      it { should be_file }
      its(:content) { should match /%bosh_sudoers ALL=\(ALL\) NOPASSWD: ALL/m }
      its(:content) { should match '#includedir /etc/sudoers.d' }
    end
  end

  context 'effective GID for UID vcap' do
    describe command("id -gn vcap") do
      its (:stdout) { should eq "vcap\n" }
    end
  end

  context 'The sudo command must require authentication (stig: V-58901)' do
    describe command("egrep -sh 'NOPASSWD|!authenticate' /etc/sudoers /etc/sudoers.d/* | egrep -v '^#|%bosh_sudoers\s' --") do
      its (:stdout) { should eq('') }
    end
  end

  context 'installed by bosh_users' do
    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:$PATH\n' /root/.bashrc") do
      it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
    end

    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:$PATH\n' /home/vcap/.bashrc") do
      it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
    end

    describe file('/root/.bashrc') do
      it { should be_file }
      its(:content) { should match 'source /etc/profile.d/00-bosh-ps1' }
    end

    describe file('/home/vcap/.bashrc') do
      it { should be_file }
      its(:content) { should match 'source /etc/profile.d/00-bosh-ps1' }
    end

    describe file('/etc/skel/.bashrc') do
      it { should be_file }
      its(:content) { should match 'source /etc/profile.d/00-bosh-ps1' }
    end

    describe file('/etc/profile.d/00-bosh-ps1') do
      it { should be_file }
    end

    describe command('grep -q .bashrc /root/.profile') do
      it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
    end

    describe command('stat -c %a ~vcap') do
      it('includes restrictive permissions') { expect(subject.stdout.strip).to eq('700') }
    end

    describe user('vcap') do
      it { should be_in_group 'bosh_sshers' }
    end
  end

  context '/etc/securetty' do
    context 'disallows virtual console access (stig: V-38492)' do
      describe command("grep '^vc/[0-9]+' /etc/securetty") do
        its(:stdout) { should be_empty }
      end
    end

    context 'restricts root login to system console (CIS-9.4)' do
      describe command("awk '$1 !~ /^(console|#.*|\s*)$/ { print; f=1 } END { if (!f) print \"none\" }' /etc/securetty") do
        its(:stdout) { should eq "none\n" }
      end
    end
  end

  context 'Disable IPv6 Redirect Acceptance - all (CIS-7.3.2)' do
    describe file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^[\s]*net\.ipv6\.conf\.all\.accept_redirects[\s]*=/ }
    end
  end

  # The STIG says to have the log files owned and grouped by 'root'. However, this would mean that
  # rsyslog would not be able to dropping privileges to another user. Because of this we've decided
  # it should run as the limited scope user 'syslog' which still prevents 'vcap' from reading the
  # logs (which is the original intention of the STIG).
  context 'all rsyslog-generated log files must be owned by syslog. (stig: V-38519 V-38518 V-38623)' do
    it 'secures rsyslog.conf-referenced files correctly' do
      command(
        [
          # get all logfile directives
          "grep --no-filename --recursive '/var/log/' /etc/rsyslog*",
          # filter commented directives
          "grep -v '^#'",
          # remove leading characters
          "sed 's%^[ \t]*%%' | rev | awk '{ print $1 }' | rev | sed 's%^-%%'",
          # unique tests
          'sort | uniq',
        ].join('|')
      ).stdout.split("\n").each do |logfile|
        f = file(logfile)

        expect(f).to be_owned_by('syslog') # stig: V-38518
        expect(f.group).to eq('syslog') # stig: V-38519
        expect(f).to be_mode(0600) # stig: V-38623

        expect(f).to_not be_readable_by_user('vcap')
      end
    end
  end

  context 'installed by rsyslog_logrotate' do
    describe file('/etc/logrotate.d/rsyslog') do
      it { should be_file }

      it 'should reload rsyslog on rotate' do
        expect(subject.content).to match /sudo kill -SIGHUP \$\(cat \/var\/run\/rsyslogd\.pid\)/
      end

      it 'should not restart rsyslog on rotate so that logs are not lost' do
        expect(subject.content).not_to match 'restart rsyslog'
      end

      it 'should configure the news services' do
        expect(subject.content).to match '/var/log/news/news.crit'
        expect(subject.content).to match '/var/log/news/news.err'
        expect(subject.content).to match '/var/log/news/news.notice'
      end
    end
  end

  context 'installed by rsyslog_config' do
    before do
      Open3.capture3("sudo mount --bind /dev #{ @os_image_dir }/dev")
    end

    after do
      Open3.capture3("sudo umount #{ @os_image_dir }/dev")
    end

    describe file('/etc/rsyslog.conf') do
      it { should be_file }
      its(:content) { should match '\$ModLoad omrelp' }
      its(:content) { should match '\$FileGroup syslog' } # stig: V-38519
      its(:content) { should match '\$FileOwner syslog' } # stig: V-38518
      its(:content) { should match '\$FileCreateMode 0600' } # stig: V-38623
    end

    describe user('syslog') do
      it { should exist }
      it { should be_in_group 'vcap' }
    end

    describe group('adm') do
      it { should exist }
    end

    describe group('bosh_sudoers') do
      it { should exist }
    end

    describe group('bosh_sshers') do
      it { should exist }
    end

    describe command('rsyslogd -N 1'), exclude_on_ppc64le: true do
      it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
      it('reports its version number as 8') { expect(subject.stderr).to match /version 8/ }
    end

    describe file('/etc/rsyslog.d/enable-kernel-logging.conf') do
      it { should be_file }
      its(:content) { should match('ModLoad imklog') }
    end

    describe file('/etc/rsyslog.d/avoid-startup-deadlock.conf') do
      it { should be_file }
      its(:content) { should match(/global\(processInternalMessages="on"\)/) }
    end
  end

  context 'auditd should be installed but not enabled (stig: V-38628) (stig: V-38631) (stig: V-38632)' do
    describe service('auditd') do
      # Agent is responsible for starting auditd
      it { should_not be_enabled }
    end
  end

  context 'configured by base_ssh' do
    it 'is secure' do
      expect(sshd_config).to be_mode(0600)
    end

    it 'disallows root login (stig: V-38613)', exclude_on_softlayer: true do
      expect(sshd_config.content).to match(/^PermitRootLogin no$/)
    end

    it 'allows PrintLastLog (stig: V-38484)' do
      expect(sshd_config.content).to match(/^PrintLastLog yes$/)
    end

    it 'disables insecure DSA host keys' do
      expect(sshd_config.content).to_not match(/HostKey \/etc\/ssh\/ssh_host_dsa_key$/)
    end

    it 'enables RSA, ECDSA, ED25519 host keys' do
      matches = sshd_config.content.scan(/^HostKey.*/)

      expect(matches).to contain_exactly('HostKey /etc/ssh/ssh_host_rsa_key', 'HostKey /etc/ssh/ssh_host_ecdsa_key', 'HostKey /etc/ssh/ssh_host_ed25519_key')
    end

    it 'disallows X11 forwarding' do
      expect(sshd_config.content).to match(/^X11Forwarding no$/)
      expect(sshd_config.content).to_not match(/^X11DisplayOffset/)
    end

    it 'sets MaxAuthTries to 3' do
      expect(sshd_config.content).to match(/^MaxAuthTries 3$/)
    end

    it 'sets PermitEmptyPasswords to no (stig: V-38614)' do
      expect(sshd_config.content).to match(/^PermitEmptyPasswords no$/)
    end

    it 'sets HostbasedAuthentication to no (stig: V-38612)' do
      expect(sshd_config.content).to match(/^HostbasedAuthentication no$/)
    end

    it 'sets Banner to /etc/issue.net (stig: V-38615 V-38593) (CIS-11.1)' do
      expect(sshd_config.content).to match(/^Banner \/etc\/issue.net$/)

      banner = file('/etc/issue.net')

      # multiline message
      expect(banner.content).to match('Unauthorized use is strictly prohibited. All access and activity')
      expect(banner.content).to match('is subject to logging and monitoring.')
      expect(banner).to be_mode(0644)
      expect(banner).to be_owned_by('root')
      expect(banner.group).to eq('root')
    end

    it 'sets /etc/issue (CIS-11.1)' do
      banner = file('/etc/issue')

      # multiline message
      expect(banner.content).to match('Unauthorized use is strictly prohibited. All access and activity')
      expect(banner.content).to match('is subject to logging and monitoring.')
      expect(banner).to be_mode(0644)
      expect(banner).to be_owned_by('root')
      expect(banner.group).to eq('root')
    end

    it 'has an empty /etc/motd (CIS-11.1)' do
      banner = file('/etc/motd')
      expect(banner.content).to be_empty
      expect(banner).to be_mode(0644)
      expect(banner).to be_owned_by('root')
      expect(banner.group).to eq('root')
    end

    it 'sets IgnoreRhosts to yes (stig: V-38611)' do
      expect(sshd_config.content).to match(/^IgnoreRhosts yes$/)
    end

    it 'sets ClientAliveInterval to 900 seconds (stig: V-38608)' do
      expect(sshd_config.content).to match(/^ClientAliveInterval 900$/)
    end

    it 'sets PermitUserEnvironment to no (stig: V-38616)' do
      expect(sshd_config.content).to match(/^PermitUserEnvironment no$/)
    end

    it 'sets ClientAliveCountMax to 0 (stig: V-38610)' do
      expect(sshd_config.content).to match(/^ClientAliveCountMax 0$/)
    end

    it 'sets Protocol to 2 (stig: V-38607)' do
      expect(sshd_config.content).to match(/^Protocol 2$/)
      end

    it 'sets AllowGroups to bosh_sshers (CIS 9.3.13)', exclude_on_softlayer: true do
      expect(sshd_config.content).to match(/^AllowGroups bosh_sshers$/)
    end

    it 'sets DenyUsers to root', exclude_on_softlayer: true do
      expect(sshd_config.content).to match(/^DenyUsers root$/)
    end
  end

  describe 'PAM configuration' do
    context 'blank password logins are disabled (stig: V-38497)' do
      describe command('grep -R nullok /etc/pam.d') do
        it('exits 1') { expect(subject.exit_status).to eq 1 }
        its (:stdout) { should eq('') }
      end
    end

    context 'a stronger hashing algorithm should be used (stig: V-38574)' do
      describe command('egrep -h -r "^password" /etc/pam.d | grep pam_unix.so | grep -v sha512') do
        it('exits 1') { expect(subject.exit_status).to eq 1 }
        its (:stdout) { should eq('') }
      end
    end
  end

  context 'anacron is configured' do
    describe file('/etc/anacrontab') do
      it { should be_file }

      it 'declares RANDOM_DELAY early on' do
        lines = subject.content.lines.map(&:strip)
        random_delay_index = lines.index('RANDOM_DELAY=60')
        expect(random_delay_index).not_to be_nil

        (0..random_delay_index).each do |idx|
          expect(lines[idx]).not_to(match /(\S+\s+){2}cron\./)
        end
      end
    end
  end

  context 'tftp is not installed (stig: V-38701, V-38609, V-38606)' do
    it "shouldn't be installed" do
      expect(package('tftp')).to_not be_installed
      expect(package('tftpd')).to_not be_installed
      expect(package('tftp-server')).to_not be_installed
      expect(package('atftp')).to_not be_installed
      expect(package('atftpd')).to_not be_installed
      expect(package('libnet-tftp-ruby')).to_not be_installed
      expect(package('python-tftpy')).to_not be_installed
      expect(package('tftp-hpa')).to_not be_installed
    end
  end

  context 'vsftpd is not installed (stig: V-38599)' do
    it "shouldn't be installed" do
      expect(package('vsftpd')).to_not be_installed
      expect(package('ftpd')).to_not be_installed
    end
  end

  context 'telnet-server is not installed (stig: V-38587, V-38589)' do
    it "shouldn't be installed" do
      expect(package('telnet-server')).to_not be_installed
      expect(package('telnetd')).to_not be_installed
      expect(package('telnetd-ssl')).to_not be_installed
      expect(package('telnet-server-krb5')).to_not be_installed
      expect(package('inetutils-telnetd')).to_not be_installed
      expect(package('mactelnet-server')).to_not be_installed
    end
  end

  context 'gconf2 is not installed (stig: V-43150) (stig: V-38638) (stig: V-38629) (stig: V-38630)' do
    describe package('gconf2') do
      it { should_not be_installed }
    end
  end

  context 'rsh-server is not installed (stig: V-38598, V-38591, V-38594, V-38602)' do
    describe package('rsh-server') do
      it { should_not be_installed }
    end
  end

  context '/etc/passwd file' do
    describe file('/etc/passwd') do
      it('should be owned by root user (stig: V-38450)') { should be_owned_by('root') }
      it('should be group-owned by root group (stig: V-38451)') { expect(subject.group).to eq('root') }
      it('should have mode 0644 (stig: V-38457)') { should be_mode(0644) }
    end

    context 'should not contain password hash (stig: V-38499)' do
      describe command('grep -v "^#" /etc/passwd | awk -F: \'($2 != "x") {print}\'') do
        its (:stdout) { should eq('') }
      end
    end

    context 'disable system accounts (CIS-10.2)' do
      describe command('/usr/bin/awk -F: \'$1 !~ /^(root|sync|shutdown|halt)$/ && $3 < 500 && $7 !~ /^(\/usr\/sbin\/nologin|\/sbin\/nologin|\/bin\/false)$/ { print; f=1 } END { if (!f) print "none" }\' /etc/passwd') do
        its(:stdout) { should eq("none\n") }
      end
    end
  end

  context '/etc/group file' do
    describe file('/etc/group') do
      it('should be owned by root user (stig: V-38458)') { should be_owned_by('root') }
      it('should be owned by root group (stig: V-38459)') { expect(subject.group).to eq('root') }
      it('should have mode 0644 (stig: V-38461)') { should be_mode(0644) }
    end
  end

  context '/etc/gshadow file' do
    describe file('/etc/gshadow') do
      it('should be owned by root user (stig: V-38443)') { should be_owned_by('root') }
      it('should be owned by root group (stig: V-38448)') { expect(subject.group).to eq('root')}
      it('should have mode 0 (stig: V-38449)') { should be_mode(0000) }
    end
  end

  context 'find world-writable files (stig: V-38643)' do
    describe command('find \/ -xdev -type f -perm -002') do
      its (:stdout) { should eq('') }
    end
  end

  describe file('/etc/login.defs') do
    it('should not allow users to cycle passwords quickly (stig: V-38477)') do
      expect(subject.content).to match /^PASS_MIN_DAYS 1/
    end

    it('should use an approved hashing algorithm to save the password (stig: V-38576)') do
      expect(subject.content).to match /^ENCRYPT_METHOD SHA512/
    end
  end

  # NOTE: These shared examples are executed in the OS image building spec,
  # suites and the Stemcell building spec suites. In the OS image suites
  # nothing will be excluded, which is the desired behavior... we want all OS
  # images to perform theses stages. For the Stemcell suites the exlude flags
  # here apply.
  describe 'exceptions' do
    context 'unless: vcloud / vsphere / warden / softlayer', {
      exclude_on_vsphere: true,
      exclude_on_vcloud: true,
      exclude_on_warden: true,
      exclude_on_softlayer: true,
    } do
      it 'disallows password authentication' do
        expect(sshd_config.content).to match(/^PasswordAuthentication no$/)
      end
    end

    context 'unless: softlayer', {
        exclude_on_softlayer: true,
    } do
      it 'disallows root login (stig: V-38613)' do
        expect(sshd_config.content).to match(/^PermitRootLogin no$/)
      end
    end
  end

  describe package('xinetd') do
    it('should not be installed (stig: V-38582)') { should_not be_installed }
  end

  context 'The root account must be the only account having a UID of 0 (stig: V-38500)' do
    describe command("awk -F: '($3 == 0) {print}' /etc/passwd") do
      its (:stdout) { should eq("root:x:0:0:root:/root:/bin/bash\n") }
    end
  end

  describe file('/etc/shadow') do
    it('should be owned by root user (stig: V-38502)') { expect(subject.group).to eq('root') }
    it('should be owned by root group (stig: V-38503)') { expect(subject.group).to eq('root') }
    it('should have mode 0 (stig: V-38504)') { should be_mode(0000) }

    context 'contains no system users with passwords (stig: V-38496)' do
      describe command("awk -F: '$1 !~ /^root$/ && $1 !~ /^vcap$/ && $2 !~ /^[!*]/ {print $1 \":\" $2}' /etc/shadow") do
        it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
        its (:stdout) { should eq('') }
      end
    end

    context 'contains no users with that can update their password frequently (stig: V-38477)' do
      describe command("awk -F: '$1 !~ /^root$/ && $2 !~ /^[!*]/ && $4 != \"1\" {print $1 \":\" $4}' /etc/shadow") do
        it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
        its (:stdout) { should eq('') }
      end
    end

    context 'contains no users with that can update their password frequently (stig: V-38477)' do
      describe command("awk -F: '$1 !~ /^root$/ && $2 !~ /^[!*]/ && $4 != \"1\" {print $1 \":\" $4}' /etc/shadow") do
        it('has exit status of 0') { expect(subject.exit_status).to eq 0 }
        its (:stdout) { should eq('') }
      end
    end
  end

  describe 'IP forwarding for IPv4 must not be enabled (stig: V-38511)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^net\.ipv4\.ip_forward=0$/ }
    end
  end

  describe 'address space layout randomization (ASLR)  should be enabled  (stig: V-38596)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^kernel\.randomize_va_space=2$/ }
    end
  end

  describe 'syncookies should be enabled (stig: V-38539)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^net\.ipv4\.tcp_syncookies=1$/ }
    end
  end

  describe 'IPv6 should be disabled (stig: V-38546)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^net\.ipv6\.conf\.all\.disable_ipv6=1$/ }
      its (:content) { should match /^net\.ipv6\.conf\.default\.disable_ipv6=1$/ }
    end
  end

  describe 'tcp keepalive values' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^net\.ipv4\.tcp_keepalive_time=120$/ }
      its (:content) { should match /^net\.ipv4\.tcp_keepalive_intvl=30$/ }
      its (:content) { should match /^net\.ipv4\.tcp_keepalive_probes=8$/ }
    end
  end

  describe 'root_maxkeys and maxkeys' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^kernel\.keys\.root_maxkeys=1000000$/ }
      its (:content) { should match /^kernel\.keys\.maxkeys=1000000$/ }
    end
  end

  describe 'dmesg_restrict' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^kernel\.dmesg_restrict\=1$/ }
    end
  end

  describe 'auditd configuration' do
    describe file('/var/log/audit') do
      it { should be_directory }

      describe 'Audit log directories must have mode 0755 or less permissive (750 by default) (stig: V-38493)' do
        it { should_not be_writable_by('group') }
        it { should_not be_writable_by('other') }
      end
    end

    describe file('/etc/audit/auditd.conf') do
      describe 'logging disk errors to syslog (stig: V-38464)' do
        its (:content) { should match /^disk_error_action = SYSLOG$/ }
      end

      describe 'logging disks being low on space to syslog (stig: V-54381) (stig: V-38470)' do
        its (:content) { should match /^admin_space_left_action = SYSLOG$/ }
        its (:content) { should match /^space_left_action = SYSLOG$/ }
      end

      describe 'logging disks being full to syslog (stig: V-38468)' do
        its (:content) { should match /^disk_full_action = SYSLOG$/ }
      end

      describe 'keeping the log files under a certain size (stig: V-38633)' do
        its (:content) { should match /^max_log_file = 6$/ }
      end

      describe 'rotating the logs so the disk does not run out of space (stig: V-38634)' do
        its (:content) { should match /^max_log_file_action = ROTATE$/ }
      end

      describe 'keeping the logs around for a sensible retention period (stig: V-38636)' do
        its (:content) { should match /^num_logs = 5$/ }
      end

      describe 'audit log files must be group owned by root (stig: V-38445)' do
        its (:content) { should match /^log_group = root$/ }
      end

      describe 'audit log files triggers action when storage capacity is less than 75mb (stig: V-38678)' do
        its (:content) { should match /^space_left = 75$/ }
      end

      describe 'audit log files triggers action when storage capacity is less than 50mb (this must be less than space_left) (stig: V-38678)' do
        its (:content) { should match /^admin_space_left = 50$/ }
      end
    end

    describe file('/etc/audisp/plugins.d/syslog.conf') do
      describe 'auditd logs to syslog' do
        its (:content) { should match /^active = yes$/ }
      end
    end
  end

  describe file('/etc/audit/rules.d/audit.rules') do
    describe 'loading and unloading of dynamic kernel modules must be audited (stig: V-38580)' do
      its(:content) { should match /^-w \/sbin\/insmod -p x -k modules$/ }
      its(:content) { should match /^-w \/sbin\/rmmod -p x -k modules$/ }
      its(:content) { should match /^-w \/sbin\/modprobe -p x -k modules$/ }
      its(:content) { should match /^-w \/bin\/kmod -p x -k modules$/ }
      its(:content) { should match /-a always,exit -F arch=b64 -S finit_module -S init_module -S delete_module -k modules/ }
    end

    describe 'events that modify system date and time must be recorded (CIS-8.1.4)' do
      its(:content) { should match /^-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change$/ }
      its(:content) { should match /^-a always,exit -F arch=b64 -S clock_settime -k time-change$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S clock_settime -k time-change$/ }
      its(:content) { should match /^-w \/etc\/localtime -p wa -k time-change$/ }
    end

    describe 'file deletion events must be recorded (CIS-8.1.14)' do
      its(:content) { should match /^-a always,exit -F arch=b64 -S unlink -S unlinkat -S rmdir -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S unlink -S unlinkat -S rmdir -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete$/ }
    end

    describe 'audit rules are made mutable (CIS-8.1.18)' do
      it 'should not have a -e 2 line' do
        expect(subject.content).not_to match '-e 2'
      end
    end

    describe 'record changes to sudoers file (CIS-8.1.15)' do
      its(:content) { should match /^-w \/etc\/sudoers -p wa -k scope$/ }
    end

    describe 'record login and logout events (CIS-8.1.8)' do
      its(:content) { should match /^-w \/var\/log\/faillog -p wa -k logins$/ }
      its(:content) { should match /^-w \/var\/log\/lastlog -p wa -k logins$/ }
      its(:content) { should match /^-w \/var\/log\/tallylog -p wa -k logins$/ }
      its(:content) { should match /^-w \/var\/run\/faillock -p wa -k logins$/ }
    end

    describe 'record session initiation events (CIS-8.1.9)' do
      its(:content) { should match /^-w \/var\/run\/utmp -p wa -k session$/ }
      its(:content) { should match /^-w \/var\/log\/wtmp -p wa -k session$/ }
      its(:content) { should match /^-w \/var\/log\/btmp -p wa -k session$/ }
    end

    describe 'record events that modify user/group information (CIS-8.1.5)' do
      its(:content) { should match /^-w \/etc\/group -p wa -k identity$/ }
      its(:content) { should match /^-w \/etc\/passwd -p wa -k identity$/ }
      its(:content) { should match /^-w \/etc\/gshadow -p wa -k identity$/ }
      its(:content) { should match /^-w \/etc\/shadow -p wa -k identity$/ }
      its(:content) { should match /^-w \/etc\/security\/opasswd -p wa -k identity$/ }
    end

    describe 'record events that modify system network environment (CIS-8.1.6)' do
      its(:content) { should match /^-a exit,always -F arch=b64 -S sethostname -S setdomainname -k system-locale$/ }
      its(:content) { should match /^-a exit,always -F arch=b32 -S sethostname -S setdomainname -k system-locale$/ }
      its(:content) { should match /^-w \/etc\/issue -p wa -k system-locale$/ }
      its(:content) { should match /^-w \/etc\/issue\.net -p wa -k system-locale$/ }
      its(:content) { should match /^-w \/etc\/hosts -p wa -k system-locale$/ }
      its(:content) { should match /^-w \/etc\/network -p wa -k system-locale$/ }
    end

    describe 'record events that modify systems mandatory access controls (CIS-8.1.7)' do
      its(:content) { should match /^-w \/etc\/selinux\/ -p wa -k MAC-policy$/ }
    end

    describe 'record system administrator actions (CIS-8.1.16)' do
      its(:content) { should match /^-w \/var\/log\/sudo\.log -p wa -k actions$/ }
    end

    describe 'record file system mounts (CIS-8.1.13)' do
      its(:content) { should match /^-a always,exit -F arch=b64 -S mount -F auid>=500 -F auid!=4294967295 -k mounts$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S mount -F auid>=500 -F auid!=4294967295 -k mounts$/ }
    end

    describe 'record discretionary access control permission modification events (CIS-8.1.10)' do
      its(:content) { should match /^-a always,exit -F arch=b64 -S mount -F auid>=500 -F auid!=4294967295 -k mounts$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S mount -F auid>=500 -F auid!=4294967295 -k mounts$/ }
      its(:content) { should match /^-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod$/ }
      its(:content) { should match /^-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod$/ }
      its(:content) { should match /^-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod$/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod$/ }
    end

    describe 'record unsuccessful unauthorized access attempts to files - EACCES (CIS-8.1.11)' do
      its(:content) { should match /^-a always,exit -F arch=b64 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access/ }
      its(:content) { should match /^-a always,exit -F arch=b64 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access/ }
      its(:content) { should match /^-a always,exit -F arch=b32 -S creat -S open -S open_by_handle_at -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access/ }
    end

    describe 'record use of binaries' do
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/sbin\/unix_chkpwd -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/sbin\/mount\.nfs -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/pam_timestamp_check -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/write -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/bin\/mount \-k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/newgrp -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/wall -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/passwd -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/bin\/umount \-k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/crontab -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/chfn -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/ssh-agent -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/gpasswd -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/chsh -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/chage -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/mount -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/su -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/bin\/umount -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/mount.nfs -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/netreport -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/postdrop -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/postqueue -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/usernetctl -k privileged/ }
      its(:content) { should match /^-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=\/usr\/sbin\/service -k privileged/ }
    end
  end

  describe 'record use of privileged programs (CIS-8.1.12)' do
    let(:privileged_binaries) {
      command("find /bin /sbin /usr/bin /usr/sbin /boot -xdev \\( -perm -4000 -o -perm -2000 \\) -type f")
        .stdout
        .split
    }

    describe file('/etc/audit/rules.d/audit.rules') do
      its(:content) do
        privileged_binaries.each do |privileged_binary|
          should match /^-a always,exit -F path=#{privileged_binary} -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged$/
        end
      end
    end
  end

  describe 'disabling core dumps (CIS-4.1)' do
    describe file('/etc/security/limits.conf') do
      its(:content) { should match /^\*\s+hard\s+core\s+0$/ }
    end
  end

  context 'postfix is not installed (stig: V-38622) (stig: V-38446)' do
    it "shouldn't be installed" do
      expect(package('postfix')).to_not be_installed
    end
  end

  context 'installed binaries' do
    describe file('/var/vcap/bosh/bin/sync-time') do
      it { should be_file }
      it { should be_executable }
    end
  end
  describe 'Cron logging must be implemented. (stig: V-75865)' do
    context file('/etc/rsyslog.d/50-default.conf') do
      its (:content) { should match /^cron\.\*\s+\/var\/log\/cron\.log$/ }
    end
  end
end
