require 'spec_helper'
require 'shellout_types/user'

module ShelloutTypes
  describe User, shellout_types: true do
    let(:runner) { ShelloutTypes::Chroot.new }
    let(:user) { described_class.new(user_name, runner) }

    describe '#exists?' do
      context 'when the user exists' do
        let(:user_name) { 'root' }

        it 'returns true' do
          expect(user.exists?).to eq(true)
        end
      end

      context 'when the user does not exist' do
        let(:user_name) { 'garbage' }

        it 'returns false' do
          expect(user.exists?).to eq(false)
        end
      end
    end

    describe '#in_group?' do
      # before do
      #   allow(runner).to receive(:run).with("id #{user_name}").and_return([nil, nil, user_exists_status])
      # end

      context 'when the user exists' do
        let(:user_name) { 'root' }
        # let(:user_exists_status) { 0 }

        # before do
        #   expect(runner).to receive(:run).with("id -Gn #{user_name}").and_return([group_stdout, nil, group_status])
        # end

        context 'when the group exists' do
          # let(:group_status) { 0 }
          let(:group) { 'root' }
          # let(:group_stdout) { 'root' }

          context 'and the user belongs to the group' do
            it 'returns true' do
              expect(user.in_group?(group)).to eq(true)
            end
          end

          context 'and the user does not belong to the group' do
            let(:group) { 'nogroup' }

            it 'returns false' do
              expect(user.in_group?(group)).to eq(false)
            end
          end
        end

        context 'when the group does not exist' do
          let(:group) { 'garbage' }
          # let(:group_stdout) { '' }
          # let(:group_status) { 1 }

          it 'returns false' do
            expect(user.in_group?(group)).to eq(false)
          end
        end
      end

      context 'when the user does not exist' do
        let(:user_name) { 'garbage' }
        let(:group) { 'root' }

        it 'returns false' do
          expect(user.in_group?(group)).to eq(false)
        end
      end
    end
  end
end
