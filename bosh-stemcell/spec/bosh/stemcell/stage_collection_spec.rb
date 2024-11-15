require 'spec_helper'
require 'bosh/stemcell/arch'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  describe StageCollection do
    subject(:stage_collection) { StageCollection.new(definition) }
    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
      )
    end
    let(:agent) { double }
    let(:infrastructure) { double }
    let(:operating_system) { double }

    describe '#operating_system_stages' do
      let(:operating_system) { OperatingSystem.for('ubuntu') }

      it 'has the correct stages' do
        expect(stage_collection.operating_system_stages).to eq(
          [
            :base_debootstrap,
            :base_ubuntu_firstboot,
            :base_apt,
            :base_ubuntu_build_essential,
            :base_ubuntu_packages,
            :base_file_permission,
            :base_ssh,
            :bosh_sysstat,
            :bosh_environment,
            :bosh_sysctl,
            :bosh_limits,
            :bosh_users,
            :bosh_monit,
            :bosh_ntp,
            :bosh_sudoers,
            :bosh_systemd,
            :password_policies,
            :restrict_su_command,
            :tty_config,
            :rsyslog_config,
            :system_grub,
            :vim_tiny,
            :cron_config,
            :escape_ctrl_alt_del,
            :bosh_audit_ubuntu,
            :bosh_log_audit_start,
            :clean_machine_id,
          ]
        )
      end
    end

    describe '#agent_stages' do
      let(:agent_stages) do
        [
          :bosh_go_agent,
          :blobstore_clis,
          :logrotate_config,
          :dev_tools_config,
          :static_libraries_config,
        ]
      end

      it 'returns the correct stages' do
        expect(stage_collection.agent_stages).to eq(agent_stages)
      end
    end

    describe '#build_stemcell_image_stages' do
      let(:vmware_package_stemcell_steps) {
        [
          :image_ovf_vmx,
          :image_ovf_generate,
          :prepare_ovf_image_stemcell,
        ]
      }

      context 'when using AWS' do
        let(:infrastructure) { Infrastructure.for('aws') }
        let(:aws_build_stemcell_image_stages) {
          [
            :system_network,
            :system_aws_modules,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_aws_agent_settings,
            :bosh_clean_ssh,
            :udev_aws_rules,
            :image_create_efi,
            :image_install_grub,
            :sbom_create,
            :bosh_package_list,
          ]
        }
        let(:aws_package_stemcell_stages) {
          [
            :prepare_raw_image_stemcell,
          ]
        }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'returns the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(aws_build_stemcell_image_stages)
          expect(stage_collection.package_stemcell_stages('raw')).to eq(aws_package_stemcell_stages)
        end
      end

      context 'when using Alicloud' do
        let(:infrastructure) { Infrastructure.for('alicloud') }

        let(:alicloud_build_stemcell_image_stages) {
          [
            :system_network,
            :system_alicloud,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_alicloud_agent_settings,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :sbom_create,
            :bosh_package_list,
          ]
        }

        let(:alicloud_package_stemcell_stages) {
          [
            :prepare_raw_image_stemcell,
          ]
        }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'returns the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(alicloud_build_stemcell_image_stages)
          expect(stage_collection.package_stemcell_stages('raw')).to eq(alicloud_package_stemcell_stages)
        end
      end

      context 'when using Google' do
        let(:infrastructure) { Infrastructure.for('google') }

        let(:google_build_stemcell_image_stages) {
          [
            :system_network,
            :system_google_modules,
            :system_google_packages,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_google_agent_settings,
            :bosh_clean_ssh,
            :image_create_efi,
            :image_install_grub,
            :sbom_create,
            :bosh_package_list
          ]
        }

        let(:google_package_stemcell_stages) {
          [
            :prepare_rawdisk_image_stemcell,
          ]
        }

        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'returns the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(google_build_stemcell_image_stages)
          expect(stage_collection.package_stemcell_stages('rawdisk')).to eq(google_package_stemcell_stages)
        end
      end

      context 'when using OpenStack' do
        let(:infrastructure) { Infrastructure.for('openstack') }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'has the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(
            [
              :system_network,
              :system_openstack_clock,
              :system_openstack_modules,
              :system_parameters,
              :bosh_clean,
              :bosh_harden,
              :bosh_openstack_agent_settings,
              :bosh_clean_ssh,
              :image_create,
              :image_install_grub,
              :sbom_create,
              :bosh_package_list,
            ]
          )
          expect(stage_collection.package_stemcell_stages('qcow2')).to eq(
              [
                :prepare_qcow2_image_stemcell,
              ]
          )
        end
      end

      context 'when using CloudStack' do
        let(:infrastructure) { Infrastructure.for('cloudstack') }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'has the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(
            [
              :system_network,
              :system_openstack_modules,
              :bosh_cloudstack_ubuntu_vr_metadata,
              :system_ubuntu_xen_tools,
              :system_parameters,
              :system_vhd_utils_tools,
              :bosh_clean,
              :bosh_harden,
              :bosh_cloudstack_agent_settings,
              :bosh_clean_ssh,
              :image_create,
              :image_install_grub,
              :sbom_create,
              :bosh_package_list,
            ]
          )
          expect(stage_collection.package_stemcell_stages('qcow2')).to eq(
              [
                :prepare_qcow2_image_stemcell,
              ]
          )
        end
      end

      context 'when using vSphere' do
        let(:infrastructure) { Infrastructure.for('vsphere') }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'has the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(
            [
              :system_network,
              :system_open_vm_tools,
              :system_vsphere_cdrom,
              :system_parameters,
              :bosh_clean,
              :bosh_harden,
              :bosh_vsphere_agent_settings,
              :bosh_clean_ssh,
              :image_create_efi,
              :image_install_grub,
              :sbom_create,
              :bosh_package_list,
            ]
          )
          expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
        end
      end

      context 'when using vCloud' do
        let(:infrastructure) { Infrastructure.for('vcloud') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_open_vm_tools,
                :system_vsphere_cdrom,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_vsphere_agent_settings,
                :bosh_clean_ssh,
                :image_create_efi,
                :image_install_grub,
                :sbom_create,
                :bosh_package_list,
            ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end
      end

      context 'when using Azure' do
        let(:infrastructure) { Infrastructure.for('azure') }

        let(:azure_build_stemcell_image_stages) {
          [
            :system_azure_network,
            :system_azure_init,
            :system_parameters,
            :enable_udf_module,
            :bosh_azure_chrony,
            :bosh_clean,
            :bosh_harden,
            :bosh_azure_agent_settings,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :sbom_create,
            :bosh_package_list,
          ]
        }

        let(:azure_package_stemcell_stages) {
          [
            :prepare_vhd_image_stemcell,
          ]
        }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'returns the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(azure_build_stemcell_image_stages)
          expect(stage_collection.package_stemcell_stages('vhd')).to eq(azure_package_stemcell_stages)
        end
      end

      context 'when using softlayer' do
        let(:infrastructure) { Infrastructure.for('softlayer') }

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_softlayer_open_iscsi,
                :system_softlayer_multipath_tools,
                :system_softlayer_netplan,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_softlayer_agent_settings,
                :bosh_config_root_ssh_login,
                :bosh_clean_ssh,
                :image_create_softlayer_two_partitions,
                :image_install_grub_softlayer_two_partitions,
                :bosh_package_list
              ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end
      end

      context 'when using Warden' do
        let(:infrastructure) { Infrastructure.for('warden') }
        let(:build_stemcell_image_stages) {
          [
            :system_parameters,
            :base_warden,
            :bosh_clean,
            :bosh_harden,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :sbom_create,
            :bosh_package_list
          ]
        }
        let(:package_stemcell_stages) {
          [
            :prepare_files_image_stemcell,
          ]
        }
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'returns the correct stages' do
          expect(stage_collection.build_stemcell_image_stages).to eq(build_stemcell_image_stages)
          expect(stage_collection.package_stemcell_stages('files')).to eq(package_stemcell_stages)
        end
      end
    end
  end
end
