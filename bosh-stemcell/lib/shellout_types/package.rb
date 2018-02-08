module ShelloutTypes
  class Package
    def initialize(package, chroot_cmd_runner)
      @package = package
      @chroot_cmd_runner = chroot_cmd_runner
    end

    def to_s
      @package
    end

    def installed?
      _, _, status = @chroot_cmd_runner.run(pkg_query, @package)
      status == 0
    end

    private

    def pkg_query
      stdout, _, _ = @chroot_cmd_runner.run('cat /etc/*release')
      if stdout.match /Ubuntu/
        return 'dpkg -s'
      elsif stdout.match /CentOS|openSUSE/
        return 'rpm -q'
      else
        raise "Cannot determine Linux distribution: #{stdout}"
      end
    end
  end
end
