require "spec_helper"
require "csv"
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

  let(:modules_dep) do
    [
      "kernel/sound/core/snd.ko.zst:",
      "kernel/sound/pci/snd-hda.ko.zst: kernel/sound/core/snd.ko.zst",
      "kernel/drivers/net/ethernet/google/gve/gve.ko.zst:",
      "kernel/fs/overlayfs/overlay.ko.zst:"
    ]
  end

  let(:modules_softdep) { nil }

  before do
    modules.each do |rel_path|
      path = File.join(modules_dir, rel_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "")
    end
    File.write(File.join(modules_dir, "modules.dep"), modules_dep.join("\n") + "\n") if modules_dep
    File.write(File.join(modules_dir, "modules.softdep"), modules_softdep.join("\n") + "\n") if modules_softdep
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
      expect(stderr).to include("pbpaste | scripts/retriage_kernel_modules.rb")
      expect(stderr).to include("--- BEGIN KERNEL MODULE TRIAGE DATA ---")
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(true)
    end
  end

  describe "retriaging from the job output with scripts/retriage_kernel_modules.rb" do
    let(:retriage) { File.expand_path("../../../../scripts/retriage_kernel_modules.rb", __dir__) }

    def retriage_from(log)
      # Prefix each line the way CI log viewers might.
      Open3.capture3(retriage, "-", csv, stdin_data: log.gsub(/^/, "12:34:56 \e[0m"))
    end

    def csv_row(rel_path)
      CSV.read(csv, headers: true).find { |r| r["rel_path"] == rel_path }&.to_h
    end

    context "when a new module is not listed" do
      let(:modules) { super() + %w[kernel/drivers/net/vxlan/vxlan.ko.zst] }
      let(:modules_dep) { super() + ["kernel/drivers/net/vxlan/vxlan.ko.zst: kernel/sound/core/snd.ko.zst"] }

      it "adds a triaged row and keeps the modules it depends on" do
        _, stderr, status = run_script
        expect(status).not_to be_success

        stdout, retriage_stderr, retriage_status = retriage_from(stderr)
        expect(retriage_status).to be_success, retriage_stderr
        expect(stdout).to include("Added 1 rows:\n  kernel/drivers/net/vxlan/vxlan.ko.zst\n")
        expect(stdout).to include("    remove=No (Container & Overlay Networking): Bridge, VLAN, bonding")
        expect(csv_row("kernel/drivers/net/vxlan/vxlan.ko.zst")).to include("remove" => "No")
        expect(csv_row("kernel/sound/core/snd.ko.zst")).to include(
          "remove" => "No", "category" => "Dependency of Retained Module"
        )

        _, _, status = run_script
        expect(status).to be_success
      end
    end

    context "when a remove=No module gains a dependency on a remove=Yes module" do
      let(:modules_dep) do
        super().map { |l| l.start_with?("kernel/fs/overlayfs/") ? "#{l} kernel/sound/core/snd.ko.zst" : l }
      end

      it "marks the dependency remove=No" do
        _, stderr, status = run_script
        expect(status).not_to be_success

        stdout, retriage_stderr, retriage_status = retriage_from(stderr)
        expect(retriage_status).to be_success, retriage_stderr
        expect(stdout).to include(
          "Changed 1 decisions:\n  kernel/sound/core/snd.ko.zst\n" \
          "    remove=No (Dependency of Retained Module): Required by retained module(s): overlay.\n"
        )
        expect(csv_row("kernel/sound/core/snd.ko.zst")).to include("remove" => "No")
        expect(csv_row("kernel/sound/pci/snd-hda.ko.zst")).to include("remove" => "Yes")

        _, _, status = run_script
        expect(status).to be_success
      end
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

  context "when a remove=No module depends on a remove=Yes module" do
    let(:modules_dep) do
      super() + ["kernel/drivers/net/vxlan.ko.zst: kernel/net/ipv4/udp_tunnel.ko.zst kernel/sound/core/snd.ko.zst"]
    end
    let(:modules) { super() + %w[kernel/drivers/net/vxlan.ko.zst kernel/net/ipv4/udp_tunnel.ko.zst] }
    let(:csv_rows) do
      super() + [
        "vxlan,kernel/drivers/net/vxlan.ko.zst,No,Networking,overlay",
        "udp_tunnel,kernel/net/ipv4/udp_tunnel.ko.zst,No,Networking,vxlan dependency"
      ]
    end

    it "fails listing the broken dependencies, without removing anything" do
      _, stderr, status = run_script

      expect(status).not_to be_success
      expect(stderr).to include(
        "1 dependencies of remove=No modules are marked remove=Yes in " \
        "stemcell_builder/stages/system_kernel_modules/linux-test.csv"
      )
      expect(stderr).to include("  kernel/drivers/net/vxlan.ko.zst needs kernel/sound/core/snd.ko.zst\n")
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(true)
    end
  end

  context "when a remove=No module has a soft dependency on a remove=Yes module" do
    let(:modules_softdep) do
      [
        "# Soft dependencies extracted from modules themselves.",
        "softdep snd pre: snd_hda",
        "softdep overlay pre: snd_hda platform:overlay-helper"
      ]
    end

    it "fails listing the broken soft dependency, without removing anything" do
      _, stderr, status = run_script

      expect(status).not_to be_success
      expect(stderr).to include("1 dependencies of remove=No modules are marked remove=Yes")
      expect(stderr).to include("  kernel/fs/overlayfs/overlay.ko.zst needs kernel/sound/pci/snd-hda.ko.zst (softdep)\n")
      expect(module_present?("kernel/sound/pci/snd-hda.ko.zst")).to be(true)
    end
  end

  context "when a remove=Yes module has a soft dependency on a remove=Yes module" do
    let(:modules_softdep) { ["softdep snd pre: snd_hda"] }

    it "removes both" do
      _, _, status = run_script

      expect(status).to be_success
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(false)
      expect(module_present?("kernel/sound/pci/snd-hda.ko.zst")).to be(false)
    end
  end

  context "when modules.dep is missing" do
    let(:modules_dep) { nil }

    it "fails without removing anything" do
      _, stderr, status = run_script

      expect(status).not_to be_success
      expect(stderr).to include("#{modules_dir}/modules.dep not found")
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(true)
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

  context "when a module is listed with both remove=No and remove=Yes" do
    let(:csv_rows) { super() + ["gve,kernel/drivers/net/ethernet/google/gve/gve.ko.zst,Yes,Cloud,duplicate"] }

    it "fails without removing anything" do
      _, stderr, status = run_script

      expect(status).not_to be_success
      expect(stderr).to include("with both remove=Yes and remove=No")
      expect(stderr).to include("  kernel/drivers/net/ethernet/google/gve/gve.ko.zst\n")
      expect(module_present?("kernel/drivers/net/ethernet/google/gve/gve.ko.zst")).to be(true)
      expect(module_present?("kernel/sound/core/snd.ko.zst")).to be(true)
    end
  end
end
