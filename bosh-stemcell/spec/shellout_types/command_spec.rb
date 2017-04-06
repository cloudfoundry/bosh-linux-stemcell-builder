require_relative 'spec_helper'
require 'shellout_types/command'

module ShelloutTypes
  describe Command, shellout_types: true do
    let(:chroot) { ShelloutTypes::Chroot.new }
    let(:chroot_dir) { ENV['SHELLOUT_CHROOT_DIR'] }

    let(:echo) { described_class.new("echo $PWD", chroot) }
    let(:errorful) { described_class.new("potato", chroot) }
    let(:long) { described_class.new("cat /etc/lsb-release", chroot) }
    let(:exit11) { described_class.new("exit 11", chroot) }

    describe '#stdout' do
      it 'returns stdout of running the command in the chroot dir' do
        expect(echo.stdout).to eq("/\n")
      end
    end

    describe '#exit_status' do
      it 'returns the exit status of the command' do
        expect(echo.exit_status).to eq(0)
      end

      it 'returns the exit status even if the command fails' do
        expect(exit11.exit_status).to eq(11)
      end
    end

    describe '#stderr' do
      it 'returns stderr of running the command in the chroot dir' do
        expect(errorful.stderr).to match /potato: command not found/
      end
    end
  end
end
