require 'bosh/core/shell'
require 'rspec'
require 'shellout_types/chroot'
require 'tmpdir'


RSpec.configure do |config|
  if config.inclusion_filter[:shellout_types]
    if ENV['OS_IMAGE']
      @os_image_dir = Dir.mktmpdir('os-image-rspec')
      ShelloutTypes::Chroot.chroot_dir = @os_image_dir
      config.add_setting(:os_image_dir, default: @os_image_dir)

      config.before(:suite) do
        Bosh::Core::Shell.new.run("sudo tar zxf #{ENV['OS_IMAGE']} -C #{config.os_image_dir}")
        Bosh::Core::Shell.new.run("sudo chgrp -Rh $(id -g) #{config.os_image_dir}")
        Bosh::Core::Shell.new.run("sudo chmod 775 #{config.os_image_dir}")
        if ENV['OSX']
          Bosh::Core::Shell.new.run("sudo chroot #{config.os_image_dir} /bin/bash -c \"useradd  --uid $(id -u) -G nogroup shellout\"")
        else
          Bosh::Core::Shell.new.run("sudo chroot #{config.os_image_dir} /bin/bash -c 'useradd -G nogroup shellout'")
        end
      end

      config.after(:suite) do
        Bosh::Core::Shell.new.run("sudo rm -rf #{config.os_image_dir}")
      end
    elsif ENV['SHELLOUT_CHROOT_DIR']
      ShelloutTypes::Chroot.chroot_dir = ENV['SHELLOUT_CHROOT_DIR']
    else
      warning = 'Both ENV["OS_IMAGE"] and ENV["SHELLOUT_CHROOT_DIR"] are not set, shellout types test cases are being skipped.'
      puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
      config.filter_run_excluding shellout_types: true
    end
  end
end
