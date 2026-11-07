require "spec_helper"
require "bosh/stemcell/definition"

module Bosh::Stemcell
  describe Definition do
    subject(:definition) { Bosh::Stemcell::Definition.new(infrastructure, hypervisor, operating_system) }

    let(:infrastructure) do
      instance_double(
        "Bosh::Stemcell::Infrastructure::Base",
        name: "infrastructure-name",
        hypervisor: "hypervisor-name",
        default_disk_format: "default-disk-format"
      )
    end

    let(:hypervisor) { "hypervisor" }
    let(:operating_system_version) { "operating_system_version" }
    let(:operating_system_variant) { nil }
    let(:operating_system) do
      instance_double(
        "Bosh::Stemcell::OperatingSystem::Base",
        name: "operating-system-name",
        version: operating_system_version,
        variant: operating_system_variant
      )
    end

    describe ".for" do
      it "sets the infrastructure, hypervisor, os, and os version" do
        expect(Bosh::Stemcell::Infrastructure)
          .to receive(:for)
          .with("infrastructure-name")
          .and_return(infrastructure)

        expect(Bosh::Stemcell::OperatingSystem)
          .to receive(:for)
          .with("operating-system-name", "operating-system-version")
          .and_return(operating_system)

        definition = instance_double("Bosh::Stemcell::Definition")
        expect(Bosh::Stemcell::Definition)
          .to receive(:new)
          .with(infrastructure, hypervisor, operating_system, "amd64")
          .and_return(definition)

        Bosh::Stemcell::Definition.for(
          "infrastructure-name",
          hypervisor,
          "operating-system-name",
          "operating-system-version"
        )
      end

      it "passes an explicit architecture through to the new definition" do
        expect(Bosh::Stemcell::Infrastructure)
          .to receive(:for)
          .with("infrastructure-name")
          .and_return(infrastructure)

        expect(Bosh::Stemcell::OperatingSystem)
          .to receive(:for)
          .with("operating-system-name", "operating-system-version")
          .and_return(operating_system)

        definition = instance_double("Bosh::Stemcell::Definition")
        expect(Bosh::Stemcell::Definition)
          .to receive(:new)
          .with(infrastructure, hypervisor, operating_system, "arm64")
          .and_return(definition)

        Bosh::Stemcell::Definition.for(
          "infrastructure-name",
          hypervisor,
          "operating-system-name",
          "operating-system-version",
          "arm64"
        )
      end
    end

    describe "#initialize" do
      its(:infrastructure) { should == infrastructure }
      its(:operating_system) { should == operating_system }
      its(:hypervisor_name) { should == hypervisor }

      it "defaults the architecture to amd64" do
        expect(definition.architecture).to eq("amd64")
      end

      context "when an architecture is provided" do
        subject(:definition) do
          Bosh::Stemcell::Definition.new(infrastructure, hypervisor, operating_system, "arm64")
        end

        it "uses the provided architecture" do
          expect(definition.architecture).to eq("arm64")
        end
      end
    end

    describe "#==" do
      it "compares by value instead of reference" do
        expect_eq = [
          %w[aws xen ubuntu 7],
          %w[vsphere esxi ubuntu penguin]
        ]

        expect_eq.each do |tuple|
          expect(Definition.for(*tuple)).to eq(Definition.for(*tuple))
        end

        expect_not_equal = [
          [["aws", "xen", "ubuntu", "version"], ["vsphere", "xen", "ubuntu", "version"]]
        ]
        expect_not_equal.each do |left, right|
          expect(Definition.for(*left)).to_not eq(Definition.for(*right))
        end
      end
    end

    describe "#stemcell_name" do
      it "builds a name from the infrastructure, hypervisor, os, and disk format" do
        expect(definition.stemcell_name("disk-format")).to eq(
          "infrastructure-name-hypervisor-operating-system-name-operating_system_version-disk-format"
        )
      end

      context "the os doesnt have a version" do
        let(:operating_system_version) { nil }

        it "leaves off the os version" do
          expect(definition.stemcell_name("disk-format")).to eq(
            "infrastructure-name-hypervisor-operating-system-name-disk-format"
          )
        end
      end

      context "the os has a variant" do
        let(:operating_system_variant) { "variant" }

        it "leaves off the os version" do
          expect(definition.stemcell_name("disk-format")).to eq(
            "infrastructure-name-hypervisor-operating-system-name-operating_system_version-variant-disk-format"
          )
        end
      end

      context "the disk format is the default" do
        it "leaves it off" do
          expect(definition.stemcell_name("default-disk-format")).to eq(
            "infrastructure-name-hypervisor-operating-system-name-operating_system_version"
          )
        end
      end

      context "the architecture is the default (amd64)" do
        it "leaves the architecture off the name" do
          expect(definition.stemcell_name("disk-format")).to eq(
            "infrastructure-name-hypervisor-operating-system-name-operating_system_version-disk-format"
          )
        end
      end

      context "the architecture is non-default (arm64)" do
        subject(:definition) do
          Bosh::Stemcell::Definition.new(infrastructure, hypervisor, operating_system, "arm64")
        end

        it "appends the architecture to the name" do
          expect(definition.stemcell_name("disk-format")).to eq(
            "infrastructure-name-hypervisor-operating-system-name-operating_system_version-disk-format-arm64"
          )
        end
      end
    end

    describe "disk_formats" do
      it "delegates to infrastructure#disk_formats" do
        expect(infrastructure).to receive(:disk_formats).and_return(["format1", "format2"])

        expect(definition.disk_formats).to eq(["format1", "format2"])
      end
    end
  end
end
