require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  class Definition
    attr_reader :infrastructure, :hypervisor_name, :operating_system

    def self.for(infrastructure_name, hypervisor_name, operating_system_name, operating_system_version)
      new(
        Bosh::Stemcell::Infrastructure.for(infrastructure_name),
        hypervisor_name,
        Bosh::Stemcell::OperatingSystem.for(operating_system_name, operating_system_version),
      )
    end

    def initialize(infrastructure, hypervisor_name, operating_system)
      @infrastructure = infrastructure
      @hypervisor_name = hypervisor_name
      @operating_system = operating_system
    end

    def stemcell_name(disk_format)
      stemcell_name_parts = [
        infrastructure.name,
        hypervisor_name,
        operating_system.name,
      ]
      stemcell_name_parts << operating_system.version if operating_system.version
      stemcell_name_parts << 'go_agent'
      stemcell_name_parts << disk_format unless disk_format == infrastructure.default_disk_format

      stemcell_name_parts.join('-')
    end

    def disk_formats
      infrastructure.disk_formats
    end

    def ==(other)
      infrastructure == other.infrastructure &&
        operating_system == other.operating_system
    end
  end
end
