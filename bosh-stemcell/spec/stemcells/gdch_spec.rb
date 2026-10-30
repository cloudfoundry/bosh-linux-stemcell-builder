# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

require "spec_helper"
require "bosh/stemcell/infrastructure"

describe "GDC Stemcell", stemcell_image: true do
  it_behaves_like "udf module is disabled"

  context "installed by system_parameters" do
    describe file("/var/vcap/bosh/etc/infrastructure") do
      its(:content) { should include(Bosh::Stemcell::Infrastructure::Gdch::NAME) }
    end
  end

  context "installed by bosh_disable_password_authentication" do
    describe "disallows password authentication" do
      subject { file("/etc/ssh/sshd_config") }

      its(:content) { should match(/^PasswordAuthentication no$/) }
    end
  end

  context "installed by base_ubuntu_packages_addons" do
    describe package("cloud-init") do
      it { should be_installed }
    end

    # cloud-init's rsyslog snippet is merged into 34-bosh-agent.conf so that /etc/rsyslog.d only
    # contains the builder-specified files (see stemcell_shared_examples). The rule must keep its
    # "& stop" and precede the bosh-agent rule (and therefore the 35-syslog-release-forwarding
    # catch-all and the /var/log/syslog catch-all in 50-default.conf), otherwise cloud-init
    # messages are forwarded to the log drain / duplicated into /var/log/syslog.
    describe file("/etc/rsyslog.d/34-bosh-agent.conf") do
      its(:content) { should match(/^:syslogtag, isequal, "\[CLOUDINIT\]" \/var\/log\/cloud-init\.log$/) }
      its(:content) { should match(/^& stop$/) }

      it "routes cloud-init messages (and stops) before the bosh-agent rule" do
        content = subject.content
        cloudinit_rule = content.index("[CLOUDINIT]")
        stop_action = content.index("\n& stop")
        bosh_agent_rule = content.index("if $programname == 'bosh-agent'")
        expect(cloudinit_rule).not_to be_nil
        expect(stop_action).not_to be_nil
        expect(bosh_agent_rule).not_to be_nil
        expect(cloudinit_rule).to be < stop_action
        expect(stop_action).to be < bosh_agent_rule
      end
    end

    describe file("/etc/rsyslog.d/50-default.conf") do
      its(:content) { should_not include("[CLOUDINIT]") }
    end

    # The package-provided file must be gone, not merely "not a regular file"
    describe command("test ! -e /etc/rsyslog.d/21-cloudinit.conf && test ! -L /etc/rsyslog.d/21-cloudinit.conf") do
      its(:exit_status) { should eq(0) }
    end
  end

  context "installed by system_gdch_ntp" do
    describe file("/etc/chrony/chrony.conf") do
      it { should be_file }
      its(:content) { should match("server ntp1.org.internal") }
      its(:content) { should match("server ntp2.org.internal") }
      its(:content) { should match("server ntp3.org.internal") }
    end
  end

  context "installed by bosh_gdch_agent_settings" do
    describe file("/usr/lib/systemd/system/bosh-agent.service") do
      it { should be_file }
      its(:content) { should match("StartLimitInterval=660") }
      its(:content) { should match("StartLimitBurst=10") }
      its(:content) { should match("Restart=always") }
      its(:content) { should match("RestartSec=60") }
    end

    describe file("/var/vcap/bosh/agent.json") do
      it { should be_valid_json_file }
      its(:content) { should match('"VirtioDevicePrefix": "gdch"') }
      its(:content) { should match('"ServiceManager": "systemd"') }

      if ENV["USE_METADATA_SERVER"] == "true"
        its(:content) { should match('"Type": "InstanceMetadata"') }
        its(:content) { should match('"SettingsPath": "/computeMetadata/v1/instance/attributes/bosh-settings"') }
        its(:content) { should match('"URI": "http://169.254.169.254"') }
      else
        its(:content) { should match('"Type": "File"') }
        its(:content) { should match('"SettingsPath": "/home/bosh-ssh-user/bosh-settings.json"') }
      end
    end
  end
end
