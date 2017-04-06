module ShelloutTypes
  class File
    @@chroot_dir=''

    def self.chroot_dir=(dir)
      @@chroot_dir = dir
    end

    def initialize(path)
      @path = path
    end

    def file?
      ::File.file?(filepath)
    end

    def owned_by?(username)
      cmd = ['-c', "getent passwd #{::File.stat(filepath).uid}"]
      stdout, _, status = Open3.capture3('sudo', 'chroot', @@chroot_dir, '/bin/bash', *cmd)
      raise RuntimeError, "user #{username} does not exist" if status.exitstatus == 2

      stdout.split(':').first == username
    end

    def content
      ::File.read(filepath)
    end

    def mode?(expected_mode)
      expected_mode == (::File.stat(filepath).mode & 0777)
    end

    def group
      fileGid = ::File.stat(filepath).gid
      cmd = ["-c", "getent group #{fileGid}"]
      stdout, _, status = Open3.capture3('sudo', 'chroot', @@chroot_dir, '/bin/bash', *cmd)
      raise RuntimeError, "group #{fileGid} does not exist" if status.exitstatus == 2

      stdout.split(':').first
    end

    def executable?
      (::File.stat(filepath).mode & 0111) != 0
    end

    def directory?
      ::File.directory?(filepath)
    end

    def readable_by_user?(username)
      file_stat = ::File.stat(filepath)

      if owned_by?(username)
        return (file_stat.mode & 0400) != 0
      end

      fileGid = file_stat.gid
      cmd = ["-c", "getent group #{fileGid}"]
      stdout, _, _ = Open3.capture3('sudo', 'chroot', @@chroot_dir, '/bin/bash', *cmd)
      members = stdout.strip.split(':').last.split(',')
      gid = stdout.strip.split(':')[2]

      cmd = ["-c", "getent passwd #{username}"]
      stdout, _, _ = Open3.capture3('sudo', 'chroot', @@chroot_dir, '/bin/bash', *cmd)
      gid_username = stdout.strip.split(':')[3]

      if members.include?(username) || (gid == gid_username)
        return (file_stat.mode & 0040) != 0
      end

      ::File.world_readable?(filepath) != nil
    end

    def writable_by?(by_whom)
      case by_whom
        when 'group'
          return (::File.stat(filepath).mode & 0020) != 0
        when 'other'
          return (::File.stat(filepath).mode & 0002) != 0
        else
          raise "#{by_whom} is an invalid input to writable_by?, please specify one of: ['group', 'other']"
      end
    end

    private

    def filepath
      ::File.join(@@chroot_dir, @path)
    end
  end
end
