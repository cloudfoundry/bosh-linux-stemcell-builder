require 'rbconfig'
require 'forwardable'
require 'bosh/stemcell/archive_filename'

module Bosh::Stemcell
  class BuilderOptions
    extend Forwardable

    def initialize(dependencies = {})
      @environment = dependencies.fetch(:env)
      @definition = dependencies.fetch(:definition)

      @stemcell_version = dependencies.fetch(:version)
      @os_image_tgz_path = dependencies.fetch(:os_image_tarball)
    end

    def default
      {
        'stemcell_image_name' => stemcell_image_name,
        'stemcell_version' => stemcell_version,
        'stemcell_hypervisor' => infrastructure.hypervisor,
        'stemcell_infrastructure' => infrastructure.name,
        'stemcell_operating_system' => operating_system.name,
        'stemcell_operating_system_version' => operating_system.version,
        'stemcell_operating_system_variant' => operating_system.variant,
        'ruby_bin' => ruby_bin,
        'image_create_disk_size' => image_create_disk_size,
        'os_image_tgz' => os_image_tgz_path,
      }.merge(environment_variables).merge(ovf_options)
    end

    def image_create_disk_size
      environment['DISK_SIZE'] || infrastructure.default_disk_size
    end

    attr_reader(
      :stemcell_version
    )

    private

    def_delegators(
      :@definition,
      :infrastructure,
      :operating_system,
      :agent,
    )

    attr_reader(
      :environment,
      :definition,
      :os_image_tgz_path,
    )

    def ovf_options
      if infrastructure.name == 'vsphere' || infrastructure.name == 'vcloud'
        { 'image_ovftool_path' => environment['OVFTOOL'] }
      else
        {}
      end
    end

    def environment_variables
      {
        'UBUNTU_ISO' => environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => environment['UBUNTU_MIRROR'],
        'UBUNTU_ADVANTAGE_TOKEN' => environment['UBUNTU_ADVANTAGE_TOKEN'],
      }
    end

    def stemcell_image_name
      "#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}.raw"
    end

    def ruby_bin
      environment['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
