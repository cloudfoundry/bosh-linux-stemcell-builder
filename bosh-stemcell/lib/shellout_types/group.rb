module ShelloutTypes
  class Group
    def initialize(group_name, chroot)
      @group = group_name
      @chroot = chroot
    end

    def exists?
      _, _, status = @chroot.run('getent', 'group', @group)
      status == 0
    end
  end
end
