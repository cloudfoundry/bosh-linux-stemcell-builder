require "spec_helper"

describe "Warden Stemcell", stemcell_image: true do
  it_behaves_like "udf module is disabled"

  describe file("/usr/sbin/runsvdir-start") do
    it { should be_file }
  end

  context "installed by system_parameters" do
    describe file("/var/vcap/bosh/etc/infrastructure") do
      its(:content) { should include("warden") }
    end
  end

  context "rsyslog runit configuration" do
    describe file("/etc/sv/rsyslog/run") do
      its(:content) { should include("exec rsyslogd -n") }
      it { should be_executable }
    end

    describe file("/etc/service/rsyslog") do
      it { should be_linked_to "/etc/sv/rsyslog" }
    end
  end

  context "ssh runit configuration" do
    describe file("/etc/sv/ssh/run") do
      its(:content) { should include("exec /usr/sbin/sshd -D") }
      it { should be_executable }
    end

    describe file("/etc/service/ssh") do
      it { should be_linked_to "/etc/sv/ssh" }
    end
  end

  context "cron runit configuration" do
    describe file("/etc/sv/cron/run") do
      its(:content) { should include("exec cron -f") }
      it { should be_executable }
    end

    describe file("/etc/service/cron") do
      it { should be_linked_to "/etc/sv/cron" }
    end
  end

  context "BOSH Agent configuration" do
    describe file("/var/vcap/bosh/agent.json") do
      it { should be_valid_json_file }
      its(:content) { should include('"Type": "File"') }
      its(:content) { should include('"SettingsPath": "/var/vcap/bosh/warden-cpi-agent-env.json"') }
      its(:content) { should include('"UseDefaultTmpDir": true') }
      its(:content) { should include('"UsePreformattedPersistentDisk": true') }
      its(:content) { should include('"BindMountPersistentDisk": true') }
      its(:content) { should include('"SkipDiskSetup": true') }
      its(:content) { should include('"UseMonitIptablesFirewall": true') }
    end
  end

  context "systemd unit cleanup for warden containers" do
    # The Docker CPI runs warden stemcells with `exec /sbin/init`. base_warden
    # strips non-essential stock systemd units from the boot sequence so they
    # don't contend with the monit-managed bpm jobs in the BOSH director
    # container (symptom: postgres role never created, bosh/0 never converges).
    # Keep-list mirrors the historical Docker CPI allow-list. See
    # base_warden/apply.sh and cloudfoundry/bosh-docker-cpi-release#60.
    keep_patterns = %w[
      *bosh-agent* *dbus* *journald* *logrotate* *runit* *ssh*
      *systemd-user-sessions* *systemd-tmpfiles*
    ]
    not_name = keep_patterns.map { |g| "-not -name '#{g}'" }.join(" ")
    wants = "find /etc/systemd/system /lib/systemd/system -type l -path '*.wants/*'"

    describe "non-essential units are removed from the boot sequence" do
      describe command("#{wants} #{not_name}") do
        its(:exit_status) { should eq 0 }
        its(:stdout) { should eq "" }
      end
    end

    describe "essential units are preserved (guards against an over-broad prune)" do
      describe command(wants) do
        its(:exit_status) { should eq 0 }
        its(:stdout) { should include("runit.service") }
        its(:stdout) { should include("ssh.service") }
      end
    end
  end
end
