require 'spec_helper'
require 'bosh/stemcell/disk_image'

module Bosh::Stemcell
  describe DiskImage do
    let(:shell) { instance_double('Bosh::Core::Shell', run: nil) }
    let(:kpartx_map_output) { 'add map FAKE_LOOP1p1 (252:3): 0 3997984 linear /dev/loop1 63' }
    let(:kpartx_map_output_efi) {
      "add map FAKE_LOOP1p1 (252:3): 0 3997984 linear /dev/loop1 63\nadd map FAKE_LOOP1p2 (252:3): 0 3997984 linear /dev/loop1 63"
    }
    let(:options) do
      {
        image_file_path: '/path/to/FAKE_IMAGE',
        image_mount_point: '/fake/mnt'
      }
    end

    subject(:disk_image) { DiskImage.new(options) }

    before do
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)
    end

    describe '#initialize' do
      it 'requires an image_file_path' do
        options.delete(:image_file_path)
        expect { DiskImage.new(options) }.to raise_error(/key not found: :image_file_path/)
      end

      it 'requires an mount_point' do
        options.delete(:image_mount_point)

        dir_mock = class_double('Dir').as_stubbed_const
        expect(dir_mock).to receive(:mktmpdir).and_return('/fake/tmpdir')

        expect(DiskImage.new(options).image_mount_point).to eq('/fake/tmpdir')
      end
    end

    describe '#mount' do
      it 'maps the file to a loop device' do
        losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
        allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
        expect(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)

        disk_image.mount
      end

      it 'mounts the loop device' do
        losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
        allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
        allow(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)
        expect(shell).to receive(:run).with('sudo mount /dev/mapper/FAKE_LOOP1p1 /fake/mnt', output_command: false)

        disk_image.mount
      end


      it 'mounts efi image on the loop device' do
        losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
        allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
        allow(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output_efi)
        expect(shell).to receive(:run).with('sudo mount /dev/mapper/FAKE_LOOP1p2 /fake/mnt', output_command: false)
        expect(shell).to receive(:run).with('sudo mount -o umask=0177 /dev/mapper/FAKE_LOOP1p1 /fake/mnt/boot/efi', output_command: false)

        disk_image.mount
      end

      context 'when the device does not exist' do
        let(:mount_command) { 'sudo mount /dev/mapper/FAKE_LOOP1p1 /fake/mnt' }
        let(:mount_error) do
          "Failed: '#{mount_command}' from /fake/mnt/blah/blah/bosh-stemcell, with exit status 8192\n\n"
        end

        before do
          allow(disk_image).to receive(:sleep)
        end

        it 'runs mount a second time after sleeping long enough for the device node to be created' do
          losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
          allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
          allow(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)
          expect(shell).to receive(:run).with(mount_command, output_command: false).ordered.and_raise(mount_error)
          expect(disk_image).to receive(:sleep).with(0.5)
          expect(shell).to receive(:run).with(mount_command, output_command: false).ordered

          disk_image.mount
        end

        context 'when the second mount command fails' do
          it 'raises an error' do
            losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
            allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
            allow(shell).to receive(:run).
                             with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)
            expect(shell).to receive(:run).
                               with(mount_command, output_command: false).ordered.twice.and_raise(mount_error)

            expect { disk_image.mount }.to raise_error(mount_error)
          end
        end
      end

      context 'when the mount command fails' do
        it 'runs mount a second time' do
          losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
          allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
          allow(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)
          expect(shell).to receive(:run).
            with('sudo mount /dev/mapper/FAKE_LOOP1p1 /fake/mnt', output_command: false).ordered.
            and_raise(RuntimeError, 'UNEXEPECTED')

          expect { disk_image.mount }.to raise_error(RuntimeError, 'UNEXEPECTED')
        end
      end
    end

    describe '#unmount' do
      before do
        allow(disk_image).to receive(:device).and_return('/dev/loop0') # pretend we've mounted
      end

      it 'unmounts the loop device and then unmaps the file' do
        losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
        allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
        expect(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)
        expect(shell).to receive(:run).with('sudo umount /fake/mnt', output_command: false).ordered
        expect(shell).to receive(:run).with('sudo kpartx -dv /dev/loop0', output_command: false).ordered
        expect(shell).to receive(:run).with('sudo losetup -v -d /dev/loop0', output_command: false).ordered

        disk_image.unmount
      end

      it 'unmounts efi image on the loop device and then unmaps the file' do
        losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
        allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
        expect(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output_efi)
        expect(shell).to receive(:run).with('sudo umount /fake/mnt', output_command: false).ordered
        expect(shell).to receive(:run).with('sudo kpartx -dv /dev/loop0', output_command: false).ordered
        expect(shell).to receive(:run).with('sudo losetup -v -d /dev/loop0', output_command: false).ordered

        disk_image.unmount
      end

      it 'unmaps the file even if unmounting the device fails' do
        losetup_commad = 'sudo losetup --show --find /path/to/FAKE_IMAGE'
        allow(shell).to receive(:run).with(losetup_commad, output_command: false).and_return('/dev/loop0')
        expect(shell).to receive(:run).
                           with('sudo kpartx -sav /dev/loop0', output_command: false).and_return(kpartx_map_output)
        expect(shell).to receive(:run).with('sudo umount /fake/mnt', output_command: false).and_raise
        expect(shell).to receive(:run).with('sudo kpartx -dv /dev/loop0', output_command: false).ordered
        expect(shell).to receive(:run).with('sudo losetup -v -d /dev/loop0', output_command: false).ordered

        expect { disk_image.unmount }.to raise_error RuntimeError
      end
    end
  end
end