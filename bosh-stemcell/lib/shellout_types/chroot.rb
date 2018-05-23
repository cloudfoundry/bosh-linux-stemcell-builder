require 'open3'

module ShelloutTypes
  class Chroot
    @@chroot_dir = ''

    def self.chroot_dir=(dir)
      @@chroot_dir = dir
    end

    def initialize(dir = nil)
      @chroot_dir = dir unless dir.nil?
    end

    def run(*cmd)
      cmd.unshift('mknod -m 666 /dev/urandom c 1 9 2>/dev/null;')
      cmd.unshift('mknod -m 666 /dev/random c 1 8 2>/dev/null;')
      stdout, stderr, status = Open3.capture3(
        'sudo', 'chroot', chroot_dir, '/bin/bash', '-c', cmd.join(' ')
      )
      [stdout, stderr, status.exitstatus]
    end

    def join(path)
      ::File.join(chroot_dir, path)
    end

    def chroot_dir
      @chroot_dir || @@chroot_dir
    end
  end
end
