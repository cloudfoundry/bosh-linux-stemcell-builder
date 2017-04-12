module Bosh::Stemcell
  module Infrastructure
    def self.for(name)
      case name
        when 'openstack'
          OpenStack.new
        when 'aws'
          Aws.new
        when 'google'
          Google.new
        when 'vsphere'
          Vsphere.new
        when 'warden'
          Warden.new
        when 'vcloud'
          Vcloud.new
        when 'azure'
          Azure.new
        when 'softlayer'
          Softlayer.new
        when 'null'
          NullInfrastructure.new
        else
          raise ArgumentError.new("invalid infrastructure: #{name}")
      end
    end

    class Base
      attr_reader :name, :hypervisor, :default_disk_size, :disk_formats, :stemcell_formats

      def initialize(name:, hypervisor:, disk_formats:, default_disk_size:, stemcell_formats:)
        @name = name
        @hypervisor = hypervisor
        @default_disk_size = default_disk_size
        @disk_formats = disk_formats
        @stemcell_formats = stemcell_formats
      end

      def default_disk_format
        disk_formats.first
      end

      def additional_cloud_properties
        {}
      end

      def ==(other)
        name == other.name &&
          hypervisor == other.hypervisor &&
          default_disk_size == other.default_disk_size
      end
    end

    class NullInfrastructure < Base
      def initialize
        super(
          name: 'null',
          hypervisor: 'null',
          default_disk_size: -1,
          disk_formats: [],
          stemcell_formats: []
        )
      end
    end

    class OpenStack < Base
      def initialize
        super(
          name: 'openstack',
          hypervisor: 'kvm',
          default_disk_size: 3072,
          disk_formats: ['qcow2', 'raw'],
          stemcell_formats: ['openstack-qcow2', 'openstack-raw']
        )
      end

      def additional_cloud_properties
        {'auto_disk_config' => true}
      end
    end

    class Vsphere < Base
      def initialize
        super(name: 'vsphere',
          hypervisor: 'esxi',
          default_disk_size: 3072,
          disk_formats: ['ovf'],
          stemcell_formats: ['vsphere-ova', 'vsphere-ovf']
        )
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Vcloud < Base
      def initialize
        super(
          name: 'vcloud',
          hypervisor: 'esxi',
          default_disk_size: 3072,
          disk_formats: ['ovf'],
          stemcell_formats: ['vcloud-ova', 'vcloud-ovf']
        )
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Aws < Base
      def initialize
        super(
          name: 'aws',
          hypervisor: 'xen',
          default_disk_size: 3072,
          disk_formats: ['raw'],
          stemcell_formats: ['aws-raw']
        )
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Google < Base
      def initialize
        super(name: 'google', hypervisor: 'kvm', default_disk_size: 3072, disk_formats: ['rawdisk'], stemcell_formats: ['google-rawdisk'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Warden < Base
      def initialize
        super(name: 'warden', hypervisor: 'boshlite', default_disk_size: 2048, disk_formats: ['files'], stemcell_formats: ['warden-tar'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Azure < Base
      def initialize
        super(
          name: 'azure',
          hypervisor: 'hyperv',
          default_disk_size: 3072,
          disk_formats: ['vhd'],
          stemcell_formats: ['azure-vhd']
        )
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Softlayer < Base
      def initialize
        super(
          name: 'softlayer',
          hypervisor: 'esxi',
          default_disk_size: 3072,
          disk_formats: ['ovf'],
          stemcell_formats: ['softlayer-ovf']
        )
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end
  end
end
