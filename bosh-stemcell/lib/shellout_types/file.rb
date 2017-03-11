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
      owner = Etc.getpwuid(::File.stat(filepath).uid)
      owner.name == username
    end

    def content
      ::File.read(filepath)
    end

    def mode?(expected_mode)
      expected_mode == (::File.stat(filepath).mode & 0777)
    end

    def group
      Etc.getgrgid(::File.stat(filepath).gid).name
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

      file_group = Etc::getgrgid(file_stat.gid)

      if file_group.mem.include?(username) || (file_group.gid == Etc.getgrnam(username).gid)
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
