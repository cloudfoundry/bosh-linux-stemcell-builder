require 'spec_helper'
require 'bosh/stemcell/stemcell_builder'
require 'bosh/stemcell/build_environment'
require 'bosh/stemcell/stage_collection'
require 'bosh/stemcell/stage_runner'
require 'bosh/stemcell/stemcell_packager'
require 'yaml'

describe Bosh::Stemcell::StemcellBuilder do
  subject(:builder) do
    described_class.new(
      gem_components: gem_components,
      environment: environment,
      runner: runner,
      collection: collection
    )
  end

  let(:packager) { instance_double('Bosh::Stemcell::StemcellPackager') }
  let(:env) { {} }
  let(:infrastructure) do
    Bosh::Stemcell::Infrastructure::Base.new(
      name: 'fake_infra',
      hypervisor: 'fake_hypervisor',
      default_disk_size: -1,
      disk_formats: ['qcow2', 'raw'],
      stemcell_formats: ['stemcell-format-a', 'stemcell-format-b'],
    )
  end
  let(:operating_system) { Bosh::Stemcell::OperatingSystem.for('ubuntu') }

  let(:definition) do
    Bosh::Stemcell::Definition.new(
      infrastructure,
      'fake_hypervisor',
      operating_system
    )
  end

  let(:version) { 1234 }
  let(:os_image_tarball_path) { '/path/to/os-img.tgz' }
  let(:gem_components) { double('Bosh::Dev::GemComponents', build_release_gems: nil) }
  let(:environment) do
    Bosh::Stemcell::BuildEnvironment.new(
      env,
      definition,
      version,
      os_image_tarball_path
    )
  end

  let(:collection) do
    instance_double(
      'Bosh::Stemcell::StageCollection',
      extract_operating_system_stages: [:extract_stage],
      build_stemcell_image_stages: [:build_stage],
      package_stemcell_stages: [:package_stage],
      agent_stages: [:agent_stage],
    )
  end
  let(:runner) { instance_double('Bosh::Stemcell::StageRunner', configure_and_apply: nil) }
  let(:tmp_dir) { Dir.mktmpdir }
  before do
    allow(environment).to receive(:prepare_build)
    allow(environment).to receive(:base_directory).and_return(tmp_dir)
  end
  after { FileUtils.rm_rf(tmp_dir) }

  describe '#build' do
    before { allow(packager).to receive(:package) }
    before { allow(collection).to receive(:kernel_stages).and_return([]) }

    it 'prepares the build environment' do
      expect(environment).to receive(:prepare_build)
      builder.build
    end

    it 'runs the extract OS, agent, and infrastructure stages' do
      expect(runner).to receive(:configure_and_apply).with([:extract_stage, :agent_stage, :build_stage], nil)

      builder.build
    end
  end
end
