require 'rspec/core/formatters/console_codes'
require 'shellout_types/chroot'
require_relative 'shellout_type_assertions'

RSpec.configure do |config|
  if ENV['OS_IMAGE']
    @os_image_dir = Dir.mktmpdir('os-image-rspec')
    ShelloutTypes::Chroot.chroot_dir = @os_image_dir
    config.add_setting(:os_image_dir, default: @os_image_dir)

    config.before(:all) do
      Bosh::Core::Shell.new.run("sudo tar xf #{ENV['OS_IMAGE']} -C #{config.os_image_dir}")
    end

    config.after(:all) do
      Bosh::Core::Shell.new.run("sudo rm -rf #{config.os_image_dir}")
    end
  else
    # when running stemcell testings, we need also run the os image testings again
    unless ENV['STEMCELL_IMAGE']
      warning = 'Both ENV["OS_IMAGE"] and ENV["STEMCELL_IMAGE"] are not set, os_image test cases are being skipped.'
      puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
      config.filter_run_excluding os_image: true
    end
  end
end
