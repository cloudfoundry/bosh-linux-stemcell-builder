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

    describe '#enabled_for_level?' do
      let(:service) { described_class.new('networking', chroot) }
      context 'when the service is enabled for the specific runlevel' do

        it 'returns true' do
          expect(service.enabled_for_level?(2)).to eq(true)
        end
      end

      context 'when the service is not enabled for the specific runlevel' do
        it 'returns false' do
          expect(service.enabled_for_level?(1)).to eq(false)
        end
      end
    end
  end
end

