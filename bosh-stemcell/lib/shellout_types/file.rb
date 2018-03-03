module ShelloutTypes
  class File
    def initialize(path, chroot)
      @path = path
      @chroot = chroot
    end

    def to_s
      @path
    end

    def file?
      begin
        stdout, _, _ = @chroot.run('stat', '-c', '%F', true_path_in_chroot)

        !(stdout.strip.match(/\Aregular (empty )?file\z/).nil?)
      rescue RuntimeError
        return false
      end
    end

    def owned_by?(username)
      stdout, stderr, status = @chroot.run('stat', '-c', '%u', @path)
      stdout.strip!

      raise RuntimeError, stderr if status != 0

      stdout, stderr, status = @chroot.run("getent passwd #{stdout}")
      raise RuntimeError, "user for file #{filepath} does not exist" if status == 2
      raise RuntimeError, stderr if status != 0

      passwd_split = stdout.split(':', -1)
      raise RuntimeError, "passwd has an invalid format: #{stdout}" if passwd_split.size != 7

      passwd_split.first == username
    end

    def content
      stdout, stderr, status = @chroot.run("cat", @path)
      raise RuntimeError, stderr if status != 0

      return stdout
    end

    def content_as_lines
      content.split(/\n+/)
    end

    def mode?(expected_mode)
      expected_mode == mode
    end

    def mode
      stdout, stderr, status = @chroot.run('stat', '-c', '%a', @path)
      raise RuntimeError, stderr if status != 0

      stdout.strip.to_i(8) & 0777
    end

    def group
      group_entry.first
    end

    def executable?
      stdout, stderr, status = @chroot.run('stat', '-c', '%a', @path)
      raise RuntimeError, stderr if status != 0

      (stdout.strip.to_i(8) & 0111) != 0
    end

    def directory?
      stdout, _, _ = @chroot.run('stat', '-c', '%F', true_path_in_chroot)
      stdout.strip == 'directory'
    end

    def readable_by_user?(username)
      this_mode = mode
      if owned_by?(username)
        return (this_mode & 0400) != 0
      end

      members = group_entry.last.split(',')

      stdout, stderr, status = @chroot.run("getent passwd #{username}")
      raise RuntimeError, "user #{username} does not exist" if status == 2
      raise RuntimeError, stderr if status != 0

      passwd_split = stdout.strip.split(':', -1)
      raise RuntimeError, "passwd has an invalid format: #{stdout}" if passwd_split.size != 7

      gid_for_username = passwd_split[3]

      members.map!(&:strip)

      if members.include?(username) || (gid == gid_for_username)
        return (this_mode & 0040) != 0
      end
      (mode & 0004) != 0
    end

    def writable_by?(by_whom)
      case by_whom
        when 'group'
          (mode & 0020) != 0
        when 'other'
          (mode & 0002) != 0
        else
          raise "#{by_whom} is an invalid input to writable_by?, please specify one of: ['group', 'other']"
      end
    end

    def linked_to?(target)
      true_path_in_chroot == target
    end

    private

    def true_path_in_chroot
      stdout, stderr, status = @chroot.run('readlink', '-m', @path)
      raise RuntimeError, stderr if status != 0

      stdout.strip
    end

    def filepath
      @chroot.join(@path)
    end

    def gid
      stdout, stderr, status = @chroot.run('stat', '-c', '%g', @path)
      raise RuntimeError, stderr if status != 0

      stdout.strip
    end

    def group_entry
      fetch_and_validate_group_entry_for_gid(gid)
    end

    def fetch_and_validate_group_entry_for_gid(group_id)
      stdout, stderr, status = @chroot.run("getent group #{group_id}")
      raise RuntimeError, "group #{group_id} does not exist" if status == 2
      raise RuntimeError, stderr if status != 0

      group_split = stdout.split(':', -1)
      raise RuntimeError, "group entry is an invalid format: #{stdout}" if group_split.size != 4
      return group_split
    end
  end
end
