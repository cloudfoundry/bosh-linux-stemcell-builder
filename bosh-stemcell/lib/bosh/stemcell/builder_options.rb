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
      @image_create_disk_size = dependencies.fetch(:disk_size, infrastructure.default_disk_size)
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
        'ruby_bin' => ruby_bin,
        'image_create_disk_size' => image_create_disk_size,
        'os_image_tgz' => @os_image_tgz_path,
      }.merge(environment_variables).merge(ovf_options)
    end

    attr_reader(
      :stemcell_version,
      :image_create_disk_size,
    )

    private

    def_delegators(
      :@definition,
      :infrastructure,
      :operating_system,
      :agent,
    )

    def ovf_options
      if infrastructure.name == 'vsphere' || infrastructure.name == 'vcloud'
        { 'image_ovftool_path' => @environment['OVFTOOL'] }
      else
        {}
      end
    end

    def environment_variables
      {
        'UBUNTU_ISO' => @environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => @environment['UBUNTU_MIRROR'],
        'RHN_USERNAME' => @environment['RHN_USERNAME'],
        'RHN_PASSWORD' => @environment['RHN_PASSWORD'],
      }
    end

    def stemcell_image_name
      "#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}.raw"
    end

    def ruby_bin
      @environment['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
