module Bosh::Stemcell
  module OperatingSystem

    def self.for(operating_system_name, operating_system_version = nil)
      case operating_system_name
        when 'ubuntu' then Ubuntu.new(operating_system_version)
        else raise ArgumentError.new("invalid operating system: #{operating_system_name}")
      end
    end

    class Base
      attr_reader :name, :version, :variant

      def initialize(options = {})
        @name = options.fetch(:name)
        @version = options.fetch(:version)
        @variant = options.fetch(:variant, nil)
      end

      def ==(other)
        name == other.name
      end
    end

    class Ubuntu < Base
      def initialize(version)
        (version, variant) = version.split('-') unless version.nil?
        super(name: 'ubuntu', version: version, variant: variant)
      end
    end
  end
end
