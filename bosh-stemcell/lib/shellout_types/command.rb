module ShelloutTypes
  class Command
    def initialize(cmd, chroot)
      @cmd = cmd
      @chroot = chroot
    end

    def to_s
      @cmd
    end

    def stdout
      exec
      @stdout
    end

    def stderr
      exec
      @stderr
    end

    def exit_status
      exec
      @exit_status
    end

    private

    def exec
      @stdout, @stderr, @exit_status = @chroot.run(@cmd) unless @has_run
      @has_run = true
    end
  end
end
