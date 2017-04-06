require 'spec_helper'
require 'shellout_types/chroot'

module ShelloutTypes
  describe Chroot, shellout_types: true do
    let(:chroot_dir) { ENV['SHELLOUT_CHROOT_DIR'] }

    before do
      described_class.chroot_dir = chroot_dir
    end

    describe '#chroot_dir' do
      context 'when no dir is passed on initialization' do
        it 'returns class chroot_dir value' do
          expect(described_class.new.chroot_dir).to eq(chroot_dir)
        end
      end

      context 'when dir is passed' do
        it 'overrides class chroot_dir value with given value' do
          expect(described_class.new('override').chroot_dir).to eq('override')
        end
      end
    end

    describe '#run' do
      let(:runner) { described_class.new }

      it 'runs the specified command as root' do
        stdout, stderr, status = runner.run('id', '-u')
        expect(stderr).to eq('')
        expect(status).to eq(0)
        expect(stdout).to eq("0\n") # it runs as root
      end

      it 'returns exit code and stderr' do
        _, stderr, status = runner.run('non-existent-command')
        expect(stderr).to eq("/bin/bash: non-existent-command: command not found\n")
        expect(status).to be > 0
      end

      it 'returns an integer exit code' do
        _, _, status = runner.run('cat /garbage')
        expect(status).to eq(1)
      end

      it 'runs the command in the chroot dir' do
        stdout, stderr, status = runner.run('pwd')
        expect(stderr).to eq('')
        expect(status).to eq(0)
        expect(stdout).to eq("/\n")
      end
    end
  end
end
