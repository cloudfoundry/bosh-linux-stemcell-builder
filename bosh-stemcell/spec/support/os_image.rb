require 'rspec/core/formatters/console_codes'
require 'shellout_types/chroot'
require_relative 'shellout_type_assertions'

RSpec.configure do |config|
  # shellout types tests support env variable 'OS_IMAGE', therefore check that os image tests
  # will not be executed when testing shellout types.
  unless config.inclusion_filter[:shellout_types]
    if ENV['OS_IMAGE']
      config.filter_run_including os_image: true
      @os_image_dir = Dir.mktmpdir('os-image-rspec')
      ShelloutTypes::Chroot.chroot_dir = @os_image_dir
      config.add_setting(:os_image_dir, default: @os_image_dir)

      config.before(:suite) do
        Bosh::Core::Shell.new.run("sudo tar xf #{ENV['OS_IMAGE']} -C #{config.os_image_dir}")
      end
      config.after(:suite) do
        Bosh::Core::Shell.new.run("sudo rm -rf #{config.os_image_dir}")
      end
    else
      # when running stemcell testings, we need also run the os image testings again
      if ENV['STEMCELL_IMAGE']
        config.filter_run_including os_image: true
      else
        warning = 'Both ENV["OS_IMAGE"] and ENV["STEMCELL_IMAGE"] are not set, os_image test cases are being skipped.'
        puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
      end
    end
  end
  # explicitly disable os image tests when running 'bundle exec rspec spec/' for
  # testing bosh linux stemcell builder code.
  unless config.inclusion_filter[:os_image]
    config.filter_run_excluding os_image: true
  end
end
