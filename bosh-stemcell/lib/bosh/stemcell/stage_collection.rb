require 'bosh/stemcell/definition'
require 'forwardable'

# rubocop:disable ClassLength
module Bosh::Stemcell
  class StageCollection
    extend Forwardable

    def initialize(definition)
      @definition = definition
    end

    def operating_system_stages
      ubuntu_os_stages
    end

    def kernel_stages
      if operating_system.variant == "fips"
        %I[
          system_fips_kernel
          base_fips_apt
          system_kernel_modules
        ].flatten
      else
        %i[
          system_kernel
          system_kernel_modules
        ].flatten
      end
    end

    def extract_operating_system_stages
      [
        :untar_base_os_image,
      ]
    end

    def agent_stages
      %i[
        bosh_go_agent
        blobstore_clis
        logrotate_config
        dev_tools_config
        static_libraries_config
      ]
    end

    def build_stemcell_image_stages
      stages = case infrastructure
               when Infrastructure::Aws then
                 aws_stages
               when Infrastructure::Alicloud then
                 alicloud_stages
               when Infrastructure::CloudStack then
                 cloudstack_stages
               when Infrastructure::Google then
                 google_stages
               when Infrastructure::OpenStack then
                 openstack_stages
               when Infrastructure::Vsphere then
                 vsphere_vcloud_stages
               when Infrastructure::Vcloud then
                 vsphere_vcloud_stages
               when Infrastructure::Warden then
                 warden_stages
               when Infrastructure::Azure then
                 azure_stages
               when Infrastructure::Softlayer then
                 softlayer_stages
               end

      stages.concat(finish_stemcell_stages)
    end

    def package_stemcell_stages(disk_format)
      case disk_format
      when 'raw' then
        raw_package_stages
      when 'rawdisk' then
        rawdisk_package_stages
      when 'qcow2' then
        qcow2_package_stages
      when 'ovf' then
        ovf_package_stages
      when 'vhd' then
        vhd_package_stages
      when 'vhdx' then
        vhdx_package_stages
      when 'files' then
        files_package_stages
      end
    end

    private

    def_delegators :@definition, :infrastructure, :operating_system, :agent

    def openstack_stages
      %i[
        system_network
        system_openstack_clock
        system_openstack_modules
        system_parameters
        bosh_clean
        bosh_harden
        bosh_openstack_agent_settings
        bosh_clean_ssh
        image_create
        image_install_grub
        sbom_create
      ]
    end

    def cloudstack_stages
      %i[
        system_network
        system_openstack_modules
        bosh_cloudstack_ubuntu_vr_metadata
        system_ubuntu_xen_tools
        system_parameters
        system_vhd_utils_tools
        bosh_clean
        bosh_harden
        bosh_cloudstack_agent_settings
        bosh_clean_ssh
        image_create
        image_install_grub
        sbom_create
      ]
    end


    def vsphere_vcloud_stages
      [
        :system_network,
        :system_open_vm_tools,
        :system_vsphere_cdrom,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :bosh_vsphere_agent_settings,
        :bosh_clean_ssh,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create,
      ]
    end

    def aws_stages
      [
        :system_network,
        :system_aws_modules,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :bosh_aws_agent_settings,
        :bosh_clean_ssh,
        :udev_aws_rules,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create,
      ]
    end

    def alicloud_stages
      %i[
        system_network
        system_alicloud
        system_parameters
        bosh_clean
        bosh_harden
        bosh_alicloud_agent_settings
        bosh_clean_ssh
        image_create
        image_install_grub
        sbom_create
      ]
    end

    def google_stages
      [
        :system_network,
        :system_google_modules,
        :system_google_packages,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :bosh_google_agent_settings,
        :bosh_clean_ssh,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create,
      ]
    end

    def warden_stages
      [
        :system_parameters,
        :base_warden,
        :bosh_clean,
        :bosh_harden,
        :bosh_clean_ssh,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create,
        :image_install_grub,
        :sbom_create,
      ]
    end

    def azure_stages
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
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create,
        :image_install_grub,
        :sbom_create,
      ]
    end

    def softlayer_stages
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
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_softlayer_two_partitions,
        :image_install_grub_softlayer_two_partitions,
      ]
    end

    def finish_stemcell_stages
      [
        :bosh_package_list,
      ]
    end

    def ubuntu_os_stages
      [
        :base_debootstrap,
        :base_ubuntu_firstboot,
        :base_apt,
        :base_ubuntu_build_essential,
        :base_ubuntu_packages,
        :base_file_permission,
        :base_ssh,
        :bosh_sysstat,
        bosh_steps,
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
      ].flatten
    end

    def bosh_steps
      %i[
        bosh_environment
        bosh_sysctl
        bosh_limits
        bosh_users
        bosh_monit
        bosh_ntp
        bosh_sudoers
        bosh_systemd
      ].flatten
    end

    def raw_package_stages
      [
        :prepare_raw_image_stemcell,
      ]
    end

    def rawdisk_package_stages
      [
        :prepare_rawdisk_image_stemcell,
      ]
    end

    def qcow2_package_stages
      [
        :prepare_qcow2_image_stemcell,
      ]
    end

    def ovf_package_stages
      %i[
        image_ovf_vmx
        image_ovf_generate
        prepare_ovf_image_stemcell
      ]
    end

    def vhd_package_stages
      [
        :prepare_vhd_image_stemcell,
      ]
    end

    def vhdx_package_stages
      [
        :prepare_vhdx_image_stemcell,
      ]
    end

    def files_package_stages
      [
        :prepare_files_image_stemcell,
      ]
    end
  end
end
# rubocop:enable ClassLength
