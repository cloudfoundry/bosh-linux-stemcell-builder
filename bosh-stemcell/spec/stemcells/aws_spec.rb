require "spec_helper"

describe "AWS Stemcell", stemcell_image: true do
  it_behaves_like "udf module is disabled"

  context "installed by system_parameters" do
    describe file("/var/vcap/bosh/etc/infrastructure") do
      its(:content) { should match("aws") }
    end
  end

  context "installed by bosh_disable_password_authentication" do
    describe "disallows password authentication" do
      subject { file("/etc/ssh/sshd_config") }

      its(:content) { should match(/^PasswordAuthentication no$/) }
    end
  end

  context "installed by image_install_grub" do
    describe file(grub_cfg_path) do
      it { should be_file }
      its(:content) { should match " nvme_core.io_timeout=4294967295" }
    end
  end

  context "installed by bosh_aws_agent_settings" do
    describe file("/var/vcap/bosh/agent.json") do
      it { should be_valid_json_file }

      it "sets InstanceStorageDevicePattern for NVMe instance storage" do
        config = JSON.parse(subject.content)
        expect(config.dig("Platform", "Linux", "InstanceStorageDevicePattern")).to eq("/dev/nvme*n1")
      end

      it "sets InstanceStorageManagedVolumePattern to exclude EBS volumes" do
        config = JSON.parse(subject.content)
        expect(config.dig("Platform", "Linux", "InstanceStorageManagedVolumePattern")).to eq("/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_*")
      end
    end
  end

  describe "nvme" do
    describe "nvme-id finder" do
      subject { file("/sbin/nvme-id") }

      it { should be_file }
      it { should be_executable }
      its(:content) { should match(/nvme id-ctrl/) }
    end

    describe "udev rules" do
      subject { file("/etc/udev/rules.d/70-ec2-nvme-devices.rules") }

      it { should be_file }
      its(:content) { should match %r{/sbin/nvme-id} }
    end
  end
end
