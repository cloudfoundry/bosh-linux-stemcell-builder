require 'json'
require 'logging'

namespace :stemcell do
  desc 'Build a base OS image for use in stemcells'
  task :build_os_image, [:operating_system_name, :operating_system_version, :os_image_path] do |_, args|
    begin
      require 'bosh/stemcell/archive_handler'
      require 'bosh/stemcell/build_environment'
      require 'bosh/stemcell/definition'
      require 'bosh/stemcell/os_image_builder'
      require 'bosh/stemcell/stage_collection'
      require 'bosh/stemcell/stage_runner'

      definition = Bosh::Stemcell::Definition.for('null', 'null', args.operating_system_name, args.operating_system_version)
      environment = Bosh::Stemcell::BuildEnvironment.new(
        ENV.to_hash,
        definition,
        '',
        args.os_image_path,
      )
      collection = Bosh::Stemcell::StageCollection.new(definition)
      runner = Bosh::Stemcell::StageRunner.new(
        build_path: environment.build_path,
        command_env: environment.command_env,
        settings_file: environment.settings_path,
        work_path: environment.work_path,
      )
      archive_handler = Bosh::Stemcell::ArchiveHandler.new

      builder = Bosh::Stemcell::OsImageBuilder.new(
        environment: environment,
        collection: collection,
        runner: runner,
        archive_handler: archive_handler,
      )
      builder.build(args.os_image_path)

      sh(environment.os_image_rspec_command)
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Download a remote pre-built base OS image'
  task :download_os_image, [:operating_system_name, :operating_system_version] do |_, args|
    begin
      puts "Using OS image #{args.operating_system_name}-#{args.operating_system_version}"

      mkdir_p('tmp')

      metalink_path = File.join(
        Dir.pwd,
        'bosh-stemcell',
        'image-metalinks',
        "#{args.operating_system_name}-#{args.operating_system_version}.meta4"
      )

      os_image_path = File.join(Dir.pwd, 'tmp', 'base_os_image.tgz')
      `meta4 file-download --metalink #{metalink_path} #{os_image_path}`
      raise 'Failed to download metalink' if $?.exitstatus != 0

      puts "Successfully downloaded OS image to #{os_image_path}"
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Build a stemcell with a remote pre-built base OS image'
  task :build, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :build_number] do |_, args|
    begin
      Rake::Task['stemcell:download_os_image'].invoke(
        args.operating_system_name,
        args.operating_system_version
      )

      os_image_path = File.join(Dir.pwd, 'tmp', 'base_os_image.tgz')
      args.with_defaults(build_number: '0000')

      Rake::Task['stemcell:build_with_local_os_image'].invoke(
        args.infrastructure_name,
        args.hypervisor_name,
        args.operating_system_name,
        args.operating_system_version,
        os_image_path,
        args.build_number
      )
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  desc 'Build a stemcell using a local pre-built base OS image'
  task :build_with_local_os_image, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :os_image_path, :build_number] do |_, args|
    begin
      require 'bosh/stemcell/build_environment'
      require 'bosh/stemcell/definition'
      require 'bosh/stemcell/stage_collection'
      require 'bosh/stemcell/stage_runner'
      require 'bosh/stemcell/stemcell_packager'
      require 'bosh/stemcell/stemcell_builder'

      args.with_defaults(build_number: '0000')

      definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.hypervisor_name, args.operating_system_name, args.operating_system_version)
      environment = Bosh::Stemcell::BuildEnvironment.new(
        ENV.to_hash,
        definition,
        args.build_number,
        args.os_image_path,
      )

      sh(environment.os_image_rspec_command)

      puts "Working from #{environment.work_path}..."
      puts "########################################"
      runner = Bosh::Stemcell::StageRunner.new(
        build_path: environment.build_path,
        command_env: environment.command_env,
        settings_file: environment.settings_path,
        work_path: environment.work_path,
      )

      stemcell_building_stages = Bosh::Stemcell::StageCollection.new(definition)

      builder = Bosh::Stemcell::StemcellBuilder.new(
        environment: environment,
        runner: runner,
        definition: definition,
        collection: stemcell_building_stages
      )

      packager = Bosh::Stemcell::StemcellPackager.new(
        definition: definition,
        version: environment.version,
        work_path: environment.work_path,
        tarball_path: environment.stemcell_tarball_path,
        disk_size: environment.stemcell_disk_size,
        runner: runner,
        collection: stemcell_building_stages,
      )

      builder.build

      mkdir_p('tmp')
      definition.disk_formats.each do |disk_format|
        puts "Packaging #{disk_format}..."
        stemcell_tarball = packager.package(disk_format)
        cp(stemcell_tarball, 'tmp')
      end

      sh(environment.stemcell_rspec_command)
    rescue RuntimeError => e
      print_help
      raise e
    end
  end

  def print_help
    puts "\nFor help with stemcell building, see: https://github.com/cloudfoundry/bosh-linux-stemcell-builder/blob/master/README.md\n\n"
  end
end
