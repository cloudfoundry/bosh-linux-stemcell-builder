require 'shellout_types/file'

module ShelloutTypes
  class Service
    def initialize(service_name, chroot)
      @service = service_name
      @chroot = chroot
    end

    def to_s
      @service
    end

    def enabled?
      stdout, _, _ = @chroot.run('systemctl', 'is-enabled', @service)

      return stdout.match(/^enabled$/) ? true : false
    end
  end
end
