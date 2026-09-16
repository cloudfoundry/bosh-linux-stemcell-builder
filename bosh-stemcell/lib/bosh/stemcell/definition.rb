require "bosh/stemcell/infrastructure"
require "bosh/stemcell/operating_system"

module Bosh::Stemcell
  class Definition
    # Architecture defaults to amd64 so existing stemcell builds are unaffected.
    DEFAULT_ARCHITECTURE = "amd64".freeze

    attr_reader :infrastructure, :hypervisor_name, :operating_system, :architecture

    def self.for(infrastructure_name, hypervisor_name, operating_system_name, operating_system_version, architecture = DEFAULT_ARCHITECTURE)
      new(
        Bosh::Stemcell::Infrastructure.for(infrastructure_name),
        hypervisor_name,
        Bosh::Stemcell::OperatingSystem.for(operating_system_name, operating_system_version),
        architecture
      )
    end

    def initialize(infrastructure, hypervisor_name, operating_system, architecture = DEFAULT_ARCHITECTURE)
      @infrastructure = infrastructure
      @hypervisor_name = hypervisor_name
      @operating_system = operating_system
      @architecture = architecture || DEFAULT_ARCHITECTURE
    end

    def stemcell_name(disk_format)
      stemcell_name_parts = [
        infrastructure.name,
        hypervisor_name,
        operating_system.name
      ]
      stemcell_name_parts << operating_system.version if operating_system.version
      stemcell_name_parts << operating_system.variant if operating_system.variant
      stemcell_name_parts << disk_format unless disk_format == infrastructure.default_disk_format
      # Only embed the architecture in the name for non-default (arm64) builds so
      # existing amd64 stemcell names remain byte-identical.
      stemcell_name_parts << architecture unless architecture == DEFAULT_ARCHITECTURE

      stemcell_name_parts.join("-")
    end

    def disk_formats
      infrastructure.disk_formats
    end

    def ==(other)
      infrastructure == other.infrastructure &&
        operating_system == other.operating_system &&
        architecture == other.architecture
    end
  end
end
