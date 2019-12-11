require 'shellout_types/file'

module ShelloutTypes
  class Service
    DEFAULT_RUNLEVEL = 2

    def initialize(service_name, chroot)
      @service = service_name
      @chroot = chroot
    end

    def to_s
      @service
    end

    def enabled?
      check_service_enabled(DEFAULT_RUNLEVEL)
    end

    def enabled_for_level?(runlevel)
      check_service_enabled(runlevel)
    end

    private

    def check_service_enabled(runlevel)
      stdout, stderr, status = @chroot.run('cat', '/etc/*release')
      raise RuntimeError, stderr if status != 0

      # TODO: Get off of trusty for these tests
      # See https://www.pivotaltracker.com/story/show/165516687
      # We thought production only runs inside the docker image: "main-ubuntu-chroot" which is trusty,
      # however, we saw a build failure (https://main.bosh-ci.cf-app.com/teams/main/pipelines/bosh:stemcells:ubuntu-bionic/jobs/build-os-image-master/builds/12)
      # which we think is a result of the same tests running on bionic. Until we can move the docker images off of trusty, we are opting to make this test
      # trusty-specific instead of fixing the docker images.
      if stdout.match(/Ubuntu/) && stdout.match(/Trusty/)
        check_upstart_links(runlevel) || check_init_conf(runlevel)
      elsif stdout.match /Ubuntu|CentOS|openSUSE/
        check_is_enabled_systemctl
      else
        raise "Cannot determine Linux distribution: #{stdout}"
      end
    end

    def check_upstart_links(runlevel)
      scripts_list, stderr, status = @chroot.run('ls', '-1', "/etc/rc#{runlevel}.d")
      raise RuntimeError, stderr if status != 0

      script_links = scripts_list.split("\n")
      script_for_service = script_links.select { |link| link.match(/^S\d\d#{@service}$/) }.first
      !script_for_service.nil?
    end

    def check_init_conf(runlevel)
      conf_file = File.new("/etc/init/#{@service}.conf", @chroot)
      return false unless conf_file.file?

      start_on_block = conf_file.content.match(/^start on .*(\n[\t ]+.*)*/)[0]
      if start_on_block.match(/runlevel \[\d*#{runlevel}\d*\]/) || start_on_block.match('startup')
        return true
      else
        return false
      end
    end

    def check_is_enabled_systemctl
      stdout, _, _ = @chroot.run('systemctl', 'is-enabled', @service)

      return stdout.match(/^enabled$/) ? true : false
    end
  end
end
