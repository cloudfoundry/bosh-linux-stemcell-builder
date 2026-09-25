require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"

describe "system_kernel_modules/remove_kernel_modules.sh" do
  let(:script) do
    File.expand_path(
      "../../../../stemcell_builder/stages/system_kernel_modules/remove_kernel_modules.sh",
      __dir__
    )
  end

  let(:tmpdir) { Dir.mktmpdir }
  let(:modules_dir) { File.join(tmpdir, "usr/lib/modules/7.0.0-10-generic") }
  let(:csv) { File.join(tmpdir, "linux-test.csv") }

  let(:modules) do
    %w[
      kernel/sound/core/snd.ko.zst
      kernel/sound/pci/snd-hda.ko.zst
      kernel/drivers/net/ethernet/google/gve/gve.ko.zst
      kernel/fs/overlayfs/overlay.ko.zst
    ]
  end

  let(:csv_rows) do
    [
      "snd,kernel/sound/core/snd.ko.zst,Yes,Sound,no sound hardware",
      "snd-hda,kernel/sound/pci/snd-hda.ko.zst,Yes,Sound,\"no sound hardware, really\"",
      "gve,kernel/drivers/net/ethernet/google/gve/gve.ko.zst,No,Cloud,GCP network",
      "overlay,kernel/fs/overlayfs/overlay.ko.zst,No,Filesystem,containers"
    ]
  end

  before do
    modules.each do |rel_path|
      path = File.join(modules_dir, rel_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "")
    end
    File.write(csv, (["module_name,rel_path,remove,category,reason"] + csv_rows).join("\n") + "\n")
  end

  after { FileUtils.rm_rf(tmpdir) }

  def run_script
    Open3.capture3(script, modules_dir, csv)
  end

  def module_present?(rel_path)
    File.exist?(File.join(modules_dir, rel_path))
  end

  context "when every module is listed" do
    it "removes the remove=Yes modules and prunes their empty directories" do
      _, _, status = run_script

      expect(status).to be_success
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(false)
      expect(module_present?("kernel/sound/pci/snd-hda.ko.zst")).to be(false)
      expect(File.exist?(File.join(modules_dir, "kernel/sound"))).to be(false)
    end

    it "keeps the remove=No modules" do
      stdout, _, status = run_script

      expect(status).to be_success
      expect(module_present?("kernel/drivers/net/ethernet/google/gve/gve.ko.zst")).to be(true)
      expect(module_present?("kernel/fs/overlayfs/overlay.ko.zst")).to be(true)
      expect(stdout).to include("Removed 2 kernel modules from #{modules_dir}; 2 remain.")
    end
  end

  context "when modules are not listed in the CSV" do
    let(:modules) do
      super() + %w[
        kernel/drivers/net/new-nic.ko.zst
        kernel/fs/newfs/newfs.ko.zst
      ]
    end

    it "fails listing every unlisted module and the CSV to update, without removing anything" do
      _, stderr, status = run_script

      expect(status).not_to be_success
      expect(stderr).to include(
        "2 kernel modules in #{modules_dir} are not listed in " \
        "stemcell_builder/stages/system_kernel_modules/linux-test.csv"
      )
      expect(stderr).to include("  kernel/drivers/net/new-nic.ko.zst\n")
      expect(stderr).to include("  kernel/fs/newfs/newfs.ko.zst\n")
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(true)
    end
  end

  context "when the CSV lists modules that are not present" do
    let(:csv_rows) { super() + ["gone,kernel/drivers/gone.ko.zst,Yes,Old,removed upstream"] }

    it "warns about them and still removes the remove=Yes modules" do
      stdout, _, status = run_script

      expect(status).to be_success
      expect(stdout).to include("1 modules listed in stemcell_builder/stages/system_kernel_modules/linux-test.csv are not present")
      expect(stdout).to include("  kernel/drivers/gone.ko.zst\n")
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(false)
    end
  end

  context "when a row has an invalid remove value" do
    let(:csv_rows) { super() + ["bad,kernel/drivers/bad.ko.zst,Maybe,Unknown,unsure"] }

    it "fails without removing anything" do
      _, stderr, status = run_script

      expect(status).not_to be_success
      expect(stderr).to include("must have remove=Yes or remove=No")
      expect(stderr).to include("bad,kernel/drivers/bad.ko.zst,Maybe")
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(true)
    end
  end
end
