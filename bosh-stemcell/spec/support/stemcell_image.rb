require 'bosh/stemcell/disk_image'
require 'shellout_types/chroot'
require_relative 'shellout_type_assertions'

RSpec.configure do |config|
  # do not run stemcell image tests when shellout types tests are executed.
  unless config.inclusion_filter[:shellout_types]
    if ENV['STEMCELL_IMAGE']
      # if `config.filter[exclude_on_softlayer]` is set, it means you're building the SoftLayer stemcell.
      if config.filter[:exclude_on_softlayer]
        shell = Bosh::Core::Shell.new
        verbose = true
        image_file_path = ENV['STEMCELL_IMAGE']
        device = shell.run("sudo losetup --show --find #{image_file_path}", output_command: verbose)
        kpartx_output = shell.run("sudo kpartx -sav #{device}", output_command: verbose)
        device_partition1 = kpartx_output.lines.first.split(' ')[2]
        device_partition2 = kpartx_output.lines.last.split(' ')[2]
        loopback_dev1 = "/dev/mapper/#{device_partition1}"
        loopback_dev2 = "/dev/mapper/#{device_partition2}"
        image_mount_point = Dir.mktmpdir
        config.before(:suite) do |example|
          shell.run("sudo mkdir #{image_mount_point}/boot", output_command: verbose)
          shell.run("sudo mount #{loopback_dev2} #{image_mount_point}", output_command: verbose)
          shell.run("sudo mount #{loopback_dev1} #{image_mount_point}/boot", output_command: verbose)
          ShelloutTypes::Chroot.chroot_dir = image_mount_point
        end
        config.after(:suite) do |example|
          shell.run("sudo umount #{image_mount_point}/boot", output_command: verbose)
          shell.run("sudo umount #{image_mount_point}", output_command: verbose)
        end
      else
        disk_image = Bosh::Stemcell::DiskImage.new(image_file_path: ENV['STEMCELL_IMAGE'])
        config.before(:suite) do |example|
          disk_image.mount
          ShelloutTypes::Chroot.chroot_dir = disk_image.image_mount_point
        end
        config.after(:suite) do |example|
          disk_image.unmount
        end
      end
    else
      warning = 'All stemcell_image tests are being skipped. STEMCELL_IMAGE needs to be set'
      puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
      config.filter_run_excluding stemcell_image: true
    end
  end
end
