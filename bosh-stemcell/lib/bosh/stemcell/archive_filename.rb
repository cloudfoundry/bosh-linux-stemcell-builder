require 'bosh/stemcell/arch'
require 'forwardable'

module Bosh::Stemcell
  class ArchiveFilename
    extend Forwardable

    def initialize(version, definition, base_name, disk_format)
      @version = version
      @definition = definition
      @base_name = base_name
      @disk_format = disk_format
    end

    def to_s
      stemcell_filename_parts = [
        name,
        @version,
        @definition.stemcell_name(@disk_format)
      ]

      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      if Bosh::Stemcell::Arch.ppc64le?
        "#{@base_name}-ppc64le"
      else
        @base_name
      end
    end
  end
end
