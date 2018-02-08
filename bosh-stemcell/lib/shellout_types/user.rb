module ShelloutTypes
  class User
    def initialize(user_name, chroot_cmd_runner)
      @user_name = user_name
      @chroot_cmd_runner = chroot_cmd_runner
    end

    def to_s
      @user_name
    end

    def exists?
      _, _, status = @chroot_cmd_runner.run("id #{@user_name}")
      status == 0
    end

    def in_group?(group_name)
      return false unless exists?
      stdout, _, status = @chroot_cmd_runner.run("id -Gn #{@user_name}")
      return false unless status == 0
      groups_for_user = stdout.split(' ')
      groups_for_user.include?(group_name)
    end
  end
end
