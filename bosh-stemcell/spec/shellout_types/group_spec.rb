require_relative 'spec_helper'
require 'shellout_types/group'

module ShelloutTypes
  describe Group, shellout_types: true do
    describe '#exists?' do
      let(:chroot) { ShelloutTypes::Chroot.new }
      let(:group) { described_class.new(group_name, chroot) }

      context 'when the group exists' do
        let(:group_name) { 'root' }

        it 'returns true' do
          expect(group.exists?).to eq(true)
        end
      end

      context 'when the group does not exist' do
        let(:group_name) { 'potato' }

        it 'returns false' do
          expect(group.exists?).to eq(false)
        end
      end
    end
  end
end
