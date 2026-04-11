require "open3"
require "shellwords"

module ShelloutTypes
  class Chroot
    @@chroot_dir = ""

    def self.chroot_dir=(dir)
      @@chroot_dir = dir
    end

    def self.unmount_proc
      dir = @@chroot_dir
      return if dir.empty?
      system("sudo", "umount", "#{dir}/proc", [:out, :err] => "/dev/null")
    end

    def initialize(dir = nil)
      @chroot_dir = dir unless dir.nil?
    end

    def run(*cmd)
      cmd.unshift("mknod -m 666 /dev/urandom c 1 9 2>/dev/null;")
      cmd.unshift("mknod -m 666 /dev/random c 1 8 2>/dev/null;")
      inner = cmd.join(" ")
      wrapper = <<~SH.strip
        if ! mountpoint -q #{chroot_dir}/proc 2>/dev/null; then
          mkdir -p #{chroot_dir}/proc
          mount -t proc proc #{chroot_dir}/proc
        fi
        chroot #{chroot_dir} /bin/bash -c #{inner.shellescape}
      SH
      stdout, stderr, status = Open3.capture3("sudo", "/bin/bash", "-c", wrapper)
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
