module Bosh::Stemcell
  class Arch
    def self.arch
      RbConfig::CONFIG["host_cpu"]
    end

    def self.x86_64?
      arch == "x86_64"
    end

    # GNU triplet prefix used for multiarch library paths, e.g. x86_64-linux-gnu
    def self.gnu_arch
      x86_64? ? "x86_64" : "aarch64"
    end
  end
end
