require 'spec_helper'
require 'tempfile'
require 'shellout_types/file'

module ShelloutTypes
  describe File, shellout_types: true do
    def create_user
      random_uid = rand(100) + 1 * 65535
      cmd = ["-c", "useradd -u #{random_uid} user-#{random_uid}"]
      _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail("unable to create ephemeral user") if status.exitstatus != 0

      random_uid
    end

    def create_group
      random_gid = rand(100) + 1 * 65535
      cmd = ["-c", "groupadd -g #{random_gid} group-#{random_gid}"]
      _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail("unable to create ephemeral group") if status.exitstatus != 0
      random_gid
    end

    def add_user_to_group(random_gid, user_name)
      cmd = ["-c", "usermod -a -G group-#{random_gid} #{user_name}"]
      _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail("unable to add user to group") if status.exitstatus != 0
    end

    let(:chroot_dir) {
      ENV['SHELLOUT_CHROOT_DIR']
    }
    let(:regular_file) { described_class.new(::File.basename(Tempfile.new('a-file', chroot_dir))) }
    let(:directory_file) { described_class.new(::File.basename(Dir.mktmpdir('a-dir', chroot_dir))) }
    let(:nobody_uid) { 65534 }
    let(:nogroup_gid) { 65534 }
    let(:ephemeral_user_name) { "user-#{ephemeral_uid}" }
    let(:ephemeral_group_name) { "group-#{ephemeral_gid}" }
    let(:ephemeral_uid) { create_user }
    let(:ephemeral_gid) {
      gid = create_group
      add_user_to_group(gid, ephemeral_user_name)
      gid
    }

    before do
      srand RSpec.configuration.seed
      ShelloutTypes::File.chroot_dir = chroot_dir
    end

    after do
      cmd = ["-c", "groupdel #{ephemeral_group_name}"]
      _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail("unable to remove ephemeral group") if status.exitstatus != 0

      cmd = ["-c", "userdel #{ephemeral_user_name}"]
      _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail("unable to remove ephemeral user") if status.exitstatus != 0
    end

    describe '#file?' do
      context 'when the file is a regular file' do
        it 'returns true' do
          expect(regular_file.file?).to eq(true)
        end
      end

      context 'when the file is not there' do
        let(:absent_file) { described_class.new('not-real') }

        it 'returns false' do
          expect(absent_file.file?).to eq(false)
        end
      end

      context 'when the file is actually a directory' do
        it 'returns false' do
          expect(directory_file.file?).to eq(false)
        end
      end
    end

    describe '#owned_by?' do
      let(:owned_file) {
        owned_file = Tempfile.new('a-file', chroot_dir).path
        ::File.chown(ephemeral_uid, nil, owned_file)

        described_class.new(::File.basename(owned_file))
      }

      context 'when the provided user owns the file' do
        it 'returns true' do
          expect(owned_file.owned_by?(ephemeral_user_name)).to eq(true)
        end
      end

      context 'when the provided user does not own the file' do
        it 'returns false' do
          expect(owned_file.owned_by?('fake-user')).to eq(false)
        end
      end

      context 'when the underlying file belongs to a user that does not exist' do
        let(:file_with_unknown_owner) {
          random_uid = rand(100) + 1 * 65535
          file_with_unknown_owner = Tempfile.new('a-file', chroot_dir).path
          ::File.chown(random_uid, nil, file_with_unknown_owner)

          described_class.new(::File.basename(file_with_unknown_owner))
        }

        it('should raise an error') do
          expect { file_with_unknown_owner.owned_by?(ephemeral_user_name) }.to raise_error(RuntimeError, "user #{ephemeral_user_name} does not exist")
        end
      end

      context 'when an unexpected error occurs' do

      end
    end

    describe '#content' do
      let(:file_with_content) do
        a_file = Tempfile.new('a-file', chroot_dir)
        a_file.write("here is\nmy content")
        a_file.flush
        described_class.new(::File.basename(a_file))
      end

      it 'returns the file content' do
        expect(file_with_content.content).to eq("here is\nmy content")
      end
    end

    describe '#mode?' do
      context 'when the file mode has matching u/g/o bits' do
        it 'returns true' do
          expect(regular_file.mode?(0600)).to eq(true)
        end
      end

      context 'when the file mode has some other u/g/o bits' do
        it 'returns false' do
          expect(regular_file.mode?(0777)).to eq(false)
        end
      end
    end

    describe '#group' do
      let(:group_file) {
        group_file = Tempfile.new('a-file', chroot_dir).path
        ::File.chown(nil, ephemeral_gid, group_file)

        described_class.new(::File.basename(group_file))
      }

      it 'returns the group of the file' do
        expect(group_file.group).to eq(ephemeral_group_name)
      end

      context('when the group belonging to the file does not exist') do
        let(:current_group) { rand(100) + 1 * 65535 }

        let(:testgroup_file) {
          testgroup_file = Tempfile.new('a-file', chroot_dir).path
          ::File.chown(nil, current_group, testgroup_file)

          described_class.new(::File.basename(testgroup_file))
        }

        it 'should raise' do
          expect { testgroup_file.group }.to raise_error(RuntimeError, "group #{current_group} does not exist")
        end
      end

      context 'when an unexpected error occurs' do

      end
    end

    describe '#readable_by_user?' do
      context 'when the file is owned by the specific user' do
        let(:user_file) do
          user_file = Tempfile.new('a-file', chroot_dir).path
          ::File.chown(ephemeral_uid, nil, user_file)
          user_file
        end

        context 'and readable' do
          let(:user_readable_file) do
            ::File.chmod(0400, user_file)
            described_class.new(::File.basename(user_file))
          end

          it 'returns true' do
            expect(user_readable_file.readable_by_user?(ephemeral_user_name)).to eq(true)
          end
        end

        context 'and not readable' do
          let(:user_unreadable_file) do
            ::File.chmod(0200, user_file)
            described_class.new(::File.basename(user_file))
          end

          it 'returns false' do
            expect(user_unreadable_file.readable_by_user?(ephemeral_user_name)).to eq(false)
          end
        end
      end

      context 'when the user does not own the file' do
        context 'and the user gid matches the gid of the file' do
          let(:group_file) do
            group_file = Tempfile.new('a-file', chroot_dir).path
            ::File.chown(nobody_uid, ephemeral_gid, group_file)
            group_file
          end

          context 'and the file is group readable' do
            let(:group_readable_file) do
              ::File.chmod(0040, group_file)
              described_class.new(::File.basename(group_file))
            end

            it 'returns true' do
              expect(group_readable_file.readable_by_user?(ephemeral_user_name)).to eq(true)
            end
          end

        end

        context 'and the user belongs to the file group members' do
          let(:group_name_with_members) { "group-#{group_with_members}" }

          let(:group_with_members) {
            random_gid = create_group
            add_user_to_group(random_gid, ephemeral_user_name)
            random_gid
          }


          let(:group_file) do
            group_file = Tempfile.new('a-file', chroot_dir).path
            ::File.chown(nobody_uid, group_with_members, group_file)
            group_file
          end

          after do
            cmd = ["-c", "groupdel #{group_name_with_members}"]
            _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
            fail("unable to remove ephemeral group") if status.exitstatus != 0
          end

          context 'and the file is group readable' do
            let(:group_readable_file) do
              ::File.chmod(0040, group_file)
              described_class.new(::File.basename(group_file))
            end

            it 'returns true' do
              expect(group_readable_file.readable_by_user?(ephemeral_user_name)).to eq(true)
            end
          end

          context 'and the file is not group readable' do
            let(:group_unreadable_file) do
              ::File.chmod(0020, group_file)
              described_class.new(::File.basename(group_file))
            end

            it 'returns false' do
              expect(group_unreadable_file.readable_by_user?(ephemeral_user_name)).to eq(false)
            end
          end
        end
      end

      context 'when the user is not the owner or file group member' do
        let(:world_file) do
          world_file = Tempfile.new('a-file', chroot_dir).path
          ::File.chown(nobody_uid, nogroup_gid, world_file)
          world_file
        end

        context 'and the file is world readable' do
          let(:world_readable_file) do
            ::File.chmod(0004, world_file)
            described_class.new(::File.basename(world_file))
          end

          it 'returns true' do
            expect(world_readable_file.readable_by_user?(ephemeral_user_name)).to eq(true)
          end
        end

        context 'and the file is not world readable' do
          let(:world_unreadable_file) do
            ::File.chmod(0002, world_file)
            described_class.new(::File.basename(world_file))
          end

          it 'returns false' do
            expect(world_unreadable_file.readable_by_user?(ephemeral_user_name)).to eq(false)
          end
        end
      end
    end

    describe '#writable_by?' do
      let(:base_file) do
        Tempfile.new('a-file', chroot_dir).path
      end

      context 'when the file is writeable by its group' do
        let(:group_writable_file) do
          ::File.chmod(0020, base_file)
          described_class.new(::File.basename(base_file))
        end

        it 'returns true' do
          expect(group_writable_file.writable_by?('group')).to eq(true)
        end
      end

      context 'when the file is not writeable by its group' do
        let(:group_unwritable_file) do
          ::File.chmod(0000, base_file)
          described_class.new(::File.basename(base_file))
        end

        it 'returns false' do
          expect(group_unwritable_file.writable_by?('group')).to eq(false)
        end
      end

      context 'when the file is writeable by others' do
        let(:other_writable_file) do
          ::File.chmod(0002, base_file)
          described_class.new(::File.basename(base_file))
        end

        it 'returns true' do
          expect(other_writable_file.writable_by?('other')).to eq(true)
        end
      end

      context 'when the file is not writeable by other' do
        let(:other_unwritable_file) do
          ::File.chmod(0000, base_file)
          described_class.new(::File.basename(base_file))
        end

        it 'returns false' do
          expect(other_unwritable_file.writable_by?('other')).to eq(false)
        end
      end

      context 'when an anything other than group or other is supplied' do
        it 'returns an error' do
          name="somebody-#{rand(100)}"
          expect { regular_file.writable_by?(name) }.to raise_error(RuntimeError, "#{name} is an invalid input to writable_by?, please specify one of: ['group', 'other']")
        end
      end
    end

    describe '#executable?' do
      context 'when the file is executable' do
        let(:executable_file) do
          file_path = Tempfile.new('a-file', chroot_dir).path
          ::File.chmod(0700, file_path)
          described_class.new(::File.basename(file_path))
        end

        it 'returns true' do
          expect(executable_file.executable?).to eq(true)
        end
      end

      context 'when the file is not executable' do
        it 'returns false' do
          expect(regular_file.executable?).to eq(false)
        end
      end
    end

    describe '#directory?' do
      context 'when the file is a directory' do
        it 'returns true' do
          expect(directory_file.directory?).to eq(true)
        end
      end

      context 'when the file is not a directory' do
        it 'returns false' do
          expect(regular_file.directory?).to eq(false)
        end
      end
    end
  end
end
