require "spec_helper"
require "bosh/stemcell/arch"

module Bosh::Stemcell
  describe Arch do
    describe ".gnu_arch" do
      it "is x86_64 on an x86_64 host" do
        allow(Arch).to receive(:arch).and_return("x86_64")
        expect(Arch.gnu_arch).to eq("x86_64")
      end

      it "is aarch64 on an aarch64 host" do
        allow(Arch).to receive(:arch).and_return("aarch64")
        expect(Arch.gnu_arch).to eq("aarch64")
      end
    end
  end
end
