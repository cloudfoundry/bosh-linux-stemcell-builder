require_relative 'spec_helper'
require 'tempfile'
require 'shellout_types/file'

module ShelloutTypes
  describe File, shellout_types: true do
    def chown(uid, gid, file_name)
      cmd = ["-c"]
      chown_cmd = 'chown '
      chown_cmd += "#{uid}" unless uid.nil?
      chown_cmd += ":#{gid}" unless gid.nil?
      chown_cmd += " #{file_name}"
      cmd.push("#{chown_cmd}")

      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0
      return
    end

    def chmod(mod, file_name)
      cmd = ["-c"]
      chmod_cmd = "chmod #{mod} #{file_name}"
      cmd.push("#{chmod_cmd}")

      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0
      return
    end

    def create_user(id)
      cmd = ["-c", "useradd -u #{id} --no-user-group user-#{id}"]
      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0

      id
    end

    def create_group(id)
      cmd = ["-c", "groupadd -g #{id} group-#{id}"]
      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0
      id
    end

    def add_user_to_group(random_gid, user_name)
      cmd = ["-c", "usermod -a -G group-#{random_gid} #{user_name}"]
      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0
    end

    def set_user_group(random_gid, user_name)
      cmd = ["-c", "usermod -g group-#{random_gid} #{user_name}"]
      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0
    end

    def delete_user_and_group(username, groupname)
      cmd = ["-c", "id #{username}"]
      _, _, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)

      if status == 0
        cmd = ["-c", "userdel #{username}"]
        _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
        fail(stderr) if status.exitstatus != 0
      end

      cmd = ["-c", "groupdel #{groupname}"]
      _, stderr, status = Open3.capture3('sudo', 'chroot', chroot_dir, '/bin/bash', *cmd)
      fail(stderr) if status.exitstatus != 0
    end

    let(:chroot) { ShelloutTypes::Chroot.new }
    let(:chroot_dir) { chroot.chroot_dir }

    let(:regular_system_file) { Tempfile.new('a-file', chroot_dir) }
    let(:regular_system_filename) { ::File.basename(regular_system_file) }
    let(:regular_file) { described_class.new(regular_system_filename, chroot) }
    let(:tmp_dirname) { ::File.basename(Dir.mktmpdir('a-dir', chroot_dir)) }
    let(:directory_file) { described_class.new(tmp_dirname, chroot) }
    let(:link_path) { ::File.join(tmp_dirname, 'link') }
    let(:link) do
      chroot.run('ln', '-s', "/#{regular_system_filename}", link_path)
      described_class.new(link_path, chroot)
    end
    let(:nobody_uid) { 65534 }
    let(:nogroup_gid) { 65534 }
    let(:ephemeral_user_name) { "user-#{ephemeral_uid}" }
    let(:ephemeral_group_name) { "group-#{ephemeral_gid}" }
    let(:ephemeral_uid) { 1234 }
    let(:ephemeral_gid) { 5678 }

    before do
      srand RSpec.configuration.seed

      create_user(ephemeral_uid)
      create_group(ephemeral_gid)
      set_user_group(ephemeral_gid, ephemeral_user_name)

      allow(chroot).to receive(:run).and_call_original
    end

    after do
      delete_user_and_group(ephemeral_user_name, ephemeral_group_name)
    end

    describe '#file?' do
      context 'when the file is a regular file' do
        it 'returns true' do
          expect(regular_file.file?).to eq(true)
        end
      end

      context 'when the file is not there' do
        let(:absent_file) { described_class.new('not-real', chroot) }

        it 'returns false' do
          expect(absent_file.file?).to eq(false)
        end
      end

      context 'when the file is actually a directory' do
        it 'returns false' do
          expect(directory_file.file?).to eq(false)
        end
      end

      context 'when the file is a symlink' do
        context 'that points to a real file' do
          it 'follows the link and inspects the target' do
            expect(link.file?).to eq(true)
          end
        end

        context 'that points to a missing node' do
          before do
            link

            ::File.delete(::File.join(chroot_dir, regular_system_filename))
          end

          it 'returns false' do
            expect(link.file?).to eq(false)
          end
        end

        context 'that points to a relatively located file' do
          let(:file_in_dir) { Tempfile.new('link-target', ::File.join(chroot_dir, tmp_dirname)) }
          let(:relative_path) { ::File.basename(file_in_dir.path) }
          let(:link_to_relative) do
            chroot.run('ln', '-s', relative_path, link_path)
            described_class.new(link_path, chroot)
          end

          it 'can determine the absolute-in-chroot path of its target' do
            expect(link_to_relative.file?).to eq(true)
          end
        end
      end
    end

    describe '#owned_by?' do
      let(:owned_system_file) { Tempfile.new('a-file', chroot_dir) }
      let(:owned_file_path_relative_to_chroot) { ::File.basename(owned_system_file.path) }
      let(:owned_file) do
        chown(ephemeral_uid, nil, owned_file_path_relative_to_chroot)

        described_class.new(owned_file_path_relative_to_chroot, chroot)
      end

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
        let(:system_file) { Tempfile.new('a-file', chroot_dir) }
        let(:system_file_path_relative_to_chroot) { ::File.basename(system_file.path) }
        let(:file_with_unknown_owner) {
          random_uid = rand(100) + 1 * 65535
          chown(random_uid, nil, system_file_path_relative_to_chroot)

          described_class.new(::File.basename(system_file.path), chroot)
        }

        it('should raise an error') do
          expect { file_with_unknown_owner.owned_by?(ephemeral_user_name) }.to raise_error(RuntimeError, "user for file #{system_file.path} does not exist")
        end
      end

      context 'when an unexpected error occurs' do
        let(:stderr) { "cannot fork/exec for gid #{ephemeral_gid}" }

        it 'should raise error' do
          expect(chroot).to receive(:run).and_return(['', stderr, -1])

          expect { owned_file.owned_by?(ephemeral_user_name) }.to raise_error(RuntimeError, "cannot fork/exec for gid #{ephemeral_gid}")
        end
      end

      context 'when passwd entry is in an invalid format ' do
        let(:stdout) { 'user:x:id:gid:GECOS:home-dir' }

        it 'should raise error' do
          expect(chroot).to receive(:run).
            with('stat', '-c', '%u', owned_file_path_relative_to_chroot).
            and_return(["#{ephemeral_uid}\n", '', 0])
          expect(chroot).to receive(:run).with("getent passwd #{ephemeral_uid}").and_return([stdout, '', 0])

          expect { owned_file.owned_by?(ephemeral_user_name) }.to raise_error(RuntimeError, 'passwd has an invalid format: user:x:id:gid:GECOS:home-dir')
        end
      end
    end

    describe '#content' do
      let(:file_with_content_temp_file) do
        a_file = Tempfile.new('a-file', chroot_dir)
        a_file.write("here is\nmy content")
        a_file.flush
        a_file
      end
      let(:file_with_content) do
        described_class.new(::File.basename(file_with_content_temp_file), chroot)
      end

      it 'returns the file content' do
        expect(file_with_content.content).to eq("here is\nmy content")
      end
    end

    describe '#content_as_lines' do
      let(:file_with_content_temp_file) do
        a_file = Tempfile.new('a-file', chroot_dir)
        a_file.write("here is\nmy content")
        a_file.flush
        a_file
      end
      let(:file_with_content) do
        described_class.new(::File.basename(file_with_content_temp_file), chroot)
      end

      it 'returns the file content as an array of lines' do
        expect(file_with_content.content_as_lines).to eq(["here is","my content"])
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
      let(:group_temp_file) do
        group_file = Tempfile.new('a-file', chroot_dir)
        group_file_path_relative_to_chroot = ::File.basename(group_file.path)
        chown(nil, ephemeral_gid, group_file_path_relative_to_chroot)
        group_file
      end
      let(:group_file) do
        described_class.new(::File.basename(group_temp_file.path), chroot)
      end

      it 'returns the group of the file' do
        expect(group_file.group).to eq(ephemeral_group_name)
      end

      context('when the group entry is in an invalid format') do
        let (:stdout) { 'has-no-gid-or-members:x' }

        it 'should raise' do
          allow(chroot).to receive(:run).and_return([stdout, '', 0])

          expect { group_file.group }.to raise_error(RuntimeError, 'group entry is an invalid format: has-no-gid-or-members:x')
        end
      end

      context('when the group belonging to the file does not exist') do
        let(:current_group) { rand(100) + 1 * 65535 }
        let(:testgroup_temp_file) do
          testgroup_file = Tempfile.new('a-file', chroot_dir)
          testgroup_file_path_relative_to_chroot = ::File.basename(testgroup_file.path)
          chown(nil, current_group, testgroup_file_path_relative_to_chroot)
          testgroup_file
        end
        let(:testgroup_file) do
          described_class.new(::File.basename(testgroup_temp_file.path), chroot)
        end

        it 'should raise' do
          expect { testgroup_file.group }.to raise_error(RuntimeError, "group #{current_group} does not exist")
        end
      end

      context 'when an unexpected error occurs' do
        let (:stderr) { "cannot fork/exec for gid #{ephemeral_gid}" }

        it 'should raise an error containing the stderr' do
          expect(chroot).to receive(:run).and_return(['', stderr, -1])

          expect { group_file.group }.to raise_error(RuntimeError, "cannot fork/exec for gid #{ephemeral_gid}")
        end
      end
    end

    describe '#readable_by_user?' do
      let(:some_system_file) { Tempfile.new('a-file', chroot_dir) }
      let(:some_system_file_path_chroot) { ::File.basename(some_system_file.path) }

      let(:some_file) { described_class.new(some_system_file_path_chroot, chroot) }

      context 'when the file is owned by the specific user' do
        let(:user_file_gid) { rand(100) + 1 * 65535 }

        before do
          chown(ephemeral_uid, user_file_gid, some_system_file_path_chroot)
        end

        context 'and readable' do
          before do
            chmod("0400", some_system_file_path_chroot)
          end

          it 'returns true' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(true)
          end
        end

        context 'and not readable' do
          before do
            chmod("0200", some_system_file_path_chroot)
          end

          it 'returns false' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(false)
          end
        end
      end

      context 'when the user does not own the file but has the same group id' do
        before do
          chown(nobody_uid, ephemeral_gid, some_system_file_path_chroot)
        end

        context 'and the file is group readable' do
          before do
            chmod("0040", some_system_file_path_chroot)
          end

          it 'returns true' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(true)
          end
        end

        context 'and the file is not group readable' do
          before do
            chmod("0020", some_system_file_path_chroot)
          end

          it 'returns false' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(false)
          end
        end
      end

      context 'and the user belongs to the file group members' do
        let(:group_with_members_id) { 9999 }
        let(:group_name_with_members) { "group-#{group_with_members_id}" }

        before do
          create_group(group_with_members_id)
          add_user_to_group(group_with_members_id, ephemeral_user_name)

          chown(nobody_uid, group_with_members_id, some_system_file_path_chroot)
        end

        after do
          delete_user_and_group(ephemeral_user_name, group_name_with_members)
        end

        context 'and the file is group readable' do
          before do
            chmod("0040", some_system_file_path_chroot)
          end

          it 'returns true' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(true)
          end
        end

        context 'and the file is not group readable' do
          before do
            chmod("0020", some_system_file_path_chroot)
          end

          it 'returns false' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(false)
          end
        end
      end

      context 'when the user is not the owner or file group member' do
        before do
          chown(nobody_uid, nogroup_gid, some_system_file_path_chroot)
        end

        context 'and the file is world readable' do
          before do
            chmod("0004", some_system_file_path_chroot)
          end

          it 'returns true' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(true)
          end
        end

        context 'and the file is not world readable' do
          before do
            chmod("0002", some_system_file_path_chroot)
          end

          it 'returns false' do
            expect(some_file.readable_by_user?(ephemeral_user_name)).to eq(false)
          end
        end
      end

      context 'when the group belonging to the file does not exist' do
        let(:fake_group) { rand(100) + 1 * 65535 }
        let(:fake_group_temp_file) do
          fake_group_file = Tempfile.new('a-file', chroot_dir)
          fake_group_file_path_chroot = ::File.basename(fake_group_file.path)
          chown(nobody_uid, fake_group, fake_group_file_path_chroot)
          fake_group_file
        end
        let(:fake_group_file) {
          described_class.new(::File.basename(fake_group_temp_file.path), chroot)
        }

        it 'should raise' do
          expect { fake_group_file.readable_by_user?(ephemeral_user_name) }.to raise_error(RuntimeError, "group #{fake_group} does not exist")
        end
      end

      context 'when asking whether a nonexistent user can read the file' do
        let(:invalid_user) { "invalid-user" }

        it 'should raise' do
          expect { some_file.readable_by_user?(invalid_user) }.to raise_error(RuntimeError, "user #{invalid_user} does not exist")
        end
      end

      context 'when an error occurs trying to determine the mode' do
        before do
          expect(chroot).to receive(:run).
          with('stat', '-c', '%a', some_system_file_path_chroot).
          and_return(['', 'mode error occurs', -1])
        end

        it 'raises a relevant error' do
          expect { some_file.readable_by_user?(ephemeral_user_name) }.to raise_error(RuntimeError, 'mode error occurs')
        end
      end

      context 'when able to determine the mode for the file' do
        before do
          expect(chroot).to receive(:run).
          with('stat', '-c', '%a', some_system_file_path_chroot).
          and_return(['0777', '', 0])
        end

        context 'when able to determine the user for the file' do
          let(:getent_passwd_nobody_stdout) { "nobody:x:#{nobody_uid}:#{nobody_uid}:nobody:/nonexistent:/usr/sbin/nologin" }

          before do
            chown(nobody_uid, ephemeral_gid, some_system_file_path_chroot)
            expect(chroot).to receive(:run).
            with('stat', '-c', '%u', some_system_file_path_chroot).
            and_return(["#{nobody_uid}", '', 0])
            expect(chroot).to receive(:run).with("getent passwd #{nobody_uid}").and_return([getent_passwd_nobody_stdout, '', 0])
          end

          context 'when an unexpected error occurs while fetching the group' do
            let(:group_err) { "cannot fork/exec for gid #{ephemeral_gid}" }

            before do
              expect(chroot).to receive(:run).
              with('stat', '-c', '%g', some_system_file_path_chroot).
              and_return(["#{ephemeral_gid}", '', 0])
              expect(chroot).to receive(:run).with("getent group #{ephemeral_gid}").and_return(['', group_err, -1])
            end

            it 'should raise an error containing the stderr' do
              expect { some_file.readable_by_user?(ephemeral_user_name) }.to raise_error(RuntimeError, group_err)
            end
          end

          context 'when able to fetch the group for the file' do
            let(:getent_group_ephemeral_stdout) { "#{ephemeral_group_name}:x:#{ephemeral_gid}:" }

            before do
              expect(chroot).to receive(:run).
              with('stat', '-c', '%g', some_system_file_path_chroot).
              and_return(["#{ephemeral_gid}", '', 0])
              expect(chroot).to receive(:run).
                with("getent group #{ephemeral_gid}").
                and_return([getent_group_ephemeral_stdout, '', 0])
            end

            context 'when an unexpected error occurs while fetching the passwd entry for the specific username' do
              let(:passwd_error) { "cannot fork/exec for uid #{ephemeral_uid}" }

              before do
                expect(chroot).to receive(:run).with("getent passwd #{ephemeral_user_name}").and_return(['', passwd_error, -1])
              end

              it 'should raise an error containing the stderr' do
                expect { some_file.readable_by_user?(ephemeral_user_name) }.to raise_error(RuntimeError, passwd_error)
              end
            end

            context 'when able to fetch passwd entry but its format is invalid' do
              let(:getent_passwd_with_bad_format_stdout) { "#{ephemeral_user_name}:x:#{ephemeral_uid}:#{ephemeral_gid}:GECOS:home-dir" }

              it 'should raise an error' do
                expect(chroot).to receive(:run).with("getent passwd #{ephemeral_user_name}").and_return([getent_passwd_with_bad_format_stdout, '', 0])

                expect { some_file.readable_by_user?(ephemeral_user_name) }.to raise_error(RuntimeError, "passwd has an invalid format: #{getent_passwd_with_bad_format_stdout}")
              end
            end
          end
        end
      end
    end

    describe '#writable_by?' do
      let(:base_file) do
        Tempfile.new('a-file', chroot_dir)
      end
      let(:base_file_path_chroot) { ::File.basename(base_file.path) }


      context 'when the file is writeable by its group' do
        let(:group_writable_file) do
          chmod("0020", base_file_path_chroot)
          described_class.new(::File.basename(base_file.path), chroot)
        end

        it 'returns true' do
          expect(group_writable_file.writable_by?('group')).to eq(true)
        end
      end

      context 'when the file is not writeable by its group' do
        let(:group_unwritable_file) do
          chmod("0000", base_file_path_chroot)
          described_class.new(::File.basename(base_file.path), chroot)
        end

        it 'returns false' do
          expect(group_unwritable_file.writable_by?('group')).to eq(false)
        end
      end

      context 'when the file is writeable by others' do
        let(:other_writable_file) do
          chmod("0002", base_file_path_chroot)
          described_class.new(::File.basename(base_file.path), chroot)
        end

        it 'returns true' do
          expect(other_writable_file.writable_by?('other')).to eq(true)
        end
      end

      context 'when the file is not writeable by other' do
        let(:other_unwritable_file) do
          chmod("0000", base_file_path_chroot)
          described_class.new(::File.basename(base_file.path), chroot)
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
        let(:executable_temp_file) do
          file = Tempfile.new('a-file', chroot_dir)
          chmod("0700", ::File.basename(file.path))
          file
        end
        let(:executable_file) do
          described_class.new(::File.basename(executable_temp_file.path), chroot)
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

    describe '#linked_to?' do
      let(:target) { Tempfile.new('target-file', chroot_dir) }

      context 'when the file is a symbolic link' do
        let(:source) do
          file_path = target.path.gsub(/target/, 'source')
          ::File.symlink(target.path, file_path)
          described_class.new(::File.basename(file_path), chroot)
        end

        it 'returns true when the file links to the specified target' do
          expect(source.linked_to?(target.path)).to eq(true)
        end

        it 'returns false when the file links to a different target' do
          expect(source.linked_to?('/path/to/foo')).to eq(false)
        end
      end

      context 'when the file is not a symbolic link' do
        let(:source_temp_file) { Tempfile.new('a-file', chroot_dir) }
        let(:source) do
          described_class.new(::File.basename(source_temp_file.path), chroot)
        end
        it 'returns false' do
          expect(source.linked_to?(target.path)).to eq(false)
        end
      end
    end
  end
end
