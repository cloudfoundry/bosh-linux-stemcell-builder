require 'bosh/core/shell'
require 'bosh/stemcell/arch'

module Bosh::Stemcell
  class DiskImage

    attr_reader :image_mount_point

    def initialize(options)
      @image_file_path   = options.fetch(:image_file_path)
      @image_mount_point = options.fetch(:image_mount_point, Dir.mktmpdir)
      @verbose           = options.fetch(:verbose, false)
      @shell             = Bosh::Core::Shell.new
    end

    def mount
      mount_image
    rescue => e
      raise e unless e.message.include?("sudo mount")

      sleep 0.5
      mount_image
    end

    def unmount
      shell.run("sudo umount #{image_mount_point}/boot/efi", output_command: verbose) if efi_image
      shell.run("sudo umount #{image_mount_point}", output_command: verbose)
    ensure
      unmap_image
    end

    private

    attr_reader :image_file_path, :verbose, :shell, :device

    def mount_image
      if efi_image
        shell.run("sudo mount #{stemcell_loopback_boot_name} #{image_mount_point}", output_command: verbose)
        shell.run("sudo mount -o umask=0177 #{stemcell_loopback_efi_name} #{image_mount_point}/boot/efi", output_command: verbose)
      else
        shell.run("sudo mount #{stemcell_loopback_device_name} #{image_mount_point}", output_command: verbose)
      end
    end

    def efi_image
      return map_image.lines.length > 1
    end

    def stemcell_loopback_device_name
      split_output = map_image.split(' ')
      device_name  = split_output[2]

      File.join('/dev/mapper', device_name)
    end

    def stemcell_loopback_boot_name
      efi_partition = map_image.lines.last.split(' ')[2]
      File.join('/dev/mapper', efi_partition)
    end

    def stemcell_loopback_efi_name
      efi_partition = map_image.lines.first.split(' ')[2]
      File.join('/dev/mapper', efi_partition)
    end

    def map_image
      return @map_image if @map_image
      @device = shell.run("sudo losetup --show --find #{image_file_path}", output_command: verbose)
      @map_image = shell.run("sudo kpartx -sav #{device}", output_command: verbose)
      @map_image
    end

    def unmap_image
      shell.run("sudo kpartx -dv #{device}", output_command: verbose)
      shell.run("sudo losetup -v -d #{device}", output_command: verbose)
    end
  end
end