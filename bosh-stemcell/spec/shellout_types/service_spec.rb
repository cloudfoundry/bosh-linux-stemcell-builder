require_relative 'spec_helper'
require 'shellout_types/service'

module ShelloutTypes
  describe Service, shellout_types: true do
    let(:chroot) { ShelloutTypes::Chroot.new }

    describe '#enabled?' do
      context 'when the service is enabled' do
        let(:service) { described_class.new('networking', chroot) }

        it 'returns true' do
          expect(service.enabled?).to eq(true)
        end
      end

      context 'when the service is not enabled' do
        let(:service) { described_class.new('auditd', chroot) }

        it 'returns false' do
          expect(service.enabled?).to eq(false)
        end
      end
    end
  end
end

