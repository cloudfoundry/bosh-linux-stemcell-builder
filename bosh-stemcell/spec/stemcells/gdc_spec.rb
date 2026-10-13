# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

require "spec_helper"
require "bosh/stemcell/infrastructure"

describe "GDC Stemcell", stemcell_image: true do
  it_behaves_like "udf module is disabled"

  context "installed by system_parameters" do
    describe file("/var/vcap/bosh/etc/infrastructure") do
      its(:content) { should include(Bosh::Stemcell::Infrastructure::Gdc::NAME) }
    end
  end

  context "installed by bosh_disable_password_authentication" do
    describe "disallows password authentication" do
      subject { file("/etc/ssh/sshd_config") }

      its(:content) { should match(/^PasswordAuthentication no$/) }
    end
  end

  context "installed by system_gdc_ntp" do
    describe file("/etc/chrony/chrony.conf") do
      it { should be_file }
      its(:content) { should match("server ntp1.org.internal") }
      its(:content) { should match("server ntp2.org.internal") }
      its(:content) { should match("server ntp3.org.internal") }
    end
  end

  context "installed by bosh_gdc_agent_settings" do
    describe file("/var/vcap/bosh/agent.json") do
      it { should be_valid_json_file }

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
