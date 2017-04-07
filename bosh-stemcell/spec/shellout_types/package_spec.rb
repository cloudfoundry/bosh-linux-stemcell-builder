require_relative 'spec_helper'
require 'shellout_types/package'

module ShelloutTypes
  describe Package, shellout_types: true do
    subject(:package) { described_class.new(package_name, runner) }
    let(:runner) {
      ShelloutTypes::Chroot.new
    }

    describe '#installed?'  do
      context 'when a package is installed'  do
        let(:package_name) { 'dpkg' }

        it 'returns true' do
          expect(package.installed?).to eq(true)
        end
      end

      context 'when a package is not_installed'  do
        let(:package_name) { 'non-existent-package' }

        it 'returns false' do
          expect(package.installed?).to eq(false)
        end
      end
    end
  end
end
