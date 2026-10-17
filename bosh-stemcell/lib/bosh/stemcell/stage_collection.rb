require "bosh/stemcell/definition"
require "forwardable"

# rubocop:disable Metrics/ClassLength
module Bosh::Stemcell
  class StageCollection
    extend Forwardable

    def initialize(definition)
      @definition = definition
    end

    # Returns the list of OS image build stages for the target infrastructure.
    def operating_system_stages
      case infrastructure
      when Infrastructure::Gdc
        gdc_ubuntu_os_stages
      else
        ubuntu_os_stages
      end
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
        :untar_base_os_image
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

    # Returns the list of stemcell image build stages for the target infrastructure.
    def build_stemcell_image_stages
      stages = case infrastructure
      when Infrastructure::Aws
        aws_stages
      when Infrastructure::Alicloud
        alicloud_stages
      when Infrastructure::CloudStack
        cloudstack_stages
      when Infrastructure::Google
        google_stages
      when Infrastructure::Gdc
        gdc_stages
      when Infrastructure::OpenStack
        openstack_stages
      when Infrastructure::Vsphere
        vsphere_stages
      when Infrastructure::Warden
        warden_stages
      when Infrastructure::Azure
        azure_stages
      end

      stages.concat(finish_stemcell_stages)
    end

    def package_stemcell_stages(disk_format)
      case disk_format
      when "raw"
        raw_package_stages
      when "rawdisk"
        rawdisk_package_stages
      when "qcow2"
        qcow2_package_stages
      when "ovf"
        ovf_package_stages
      when "vhd"
        vhd_package_stages
      when "vhdx"
        vhdx_package_stages
      when "files"
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
        restore_apt_sources
        image_create_efi
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
        restore_apt_sources
        image_create_efi
        image_install_grub
        sbom_create
      ]
    end

    def vsphere_stages
      [
        :system_network,
        :system_open_vm_tools,
        :system_vsphere_cdrom,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :bosh_vsphere_agent_settings,
        :bosh_clean_ssh,
        :restore_apt_sources,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create
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
        :restore_apt_sources,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create
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
        restore_apt_sources
        image_create_efi
        image_install_grub
        sbom_create
      ]
    end

    # Returns the stemcell image build stages for Google Cloud Platform.
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
        :restore_apt_sources,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create
      ]
    end

    # Returns the stemcell image build stages for GDC.
    def gdc_stages
      agent_settings_stage = if ENV["USE_METADATA_SERVER"] == "true"
        :bosh_gdc_agent_settings_with_metadata_server
      else
        :bosh_gdc_agent_settings
      end
      [
        :system_network,
        :system_gdc_ntp,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        agent_settings_stage,
        :bosh_clean_ssh,
        :restore_apt_sources,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create
      ]
    end

    def warden_stages
      [
        :system_parameters,
        :base_warden,
        :bosh_clean,
        :bosh_harden,
        :bosh_clean_ssh,
        :restore_apt_sources,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create
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
        :restore_apt_sources,
        # when adding a stage that changes files in the image, do so before
        # this line.  Image create will make the image so any changes to the
        # filesystem after it won't apply.
        :image_create_efi,
        :image_install_grub,
        :sbom_create
      ]
    end

    def finish_stemcell_stages
      [
        :bosh_package_list
      ]
    end

    # Returns the base Ubuntu OS image build stages.
    def ubuntu_os_stages
      [
        :base_debootstrap,
        :base_ubuntu_firstboot,
        :base_apt,
        :base_ubuntu_build_essential,
        :base_ubuntu_packages,
        :bosh_systemd_resolved,
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
        :clean_machine_id
      ].flatten
    end

    # Returns the Ubuntu OS image build stages customized for GDC.
    def gdc_ubuntu_os_stages
      ubuntu_os_stages.map do |s|
        case s
        when :bosh_audit_ubuntu
          :bosh_gdc_audit_ubuntu
        when :base_ubuntu_firstboot
          :base_gdc_ubuntu_firstboot
        when :base_ubuntu_packages
          [:base_ubuntu_packages, :base_ubuntu_packages_addson]
        when :bosh_users
          [:bosh_users, :gdc_ssh_users]
        else
          s
        end
      end.flatten
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
        :prepare_raw_image_stemcell
      ]
    end

    # Returns the packaging stages for the rawdisk format.
    def rawdisk_package_stages
      case infrastructure
      when Infrastructure::Gdc
        [:prepare_gdc_rawdisk_image_stemcell]
      else
        [:prepare_rawdisk_image_stemcell]
      end
    end

    def qcow2_package_stages
      [
        :prepare_qcow2_image_stemcell
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
        :prepare_vhd_image_stemcell
      ]
    end

    def vhdx_package_stages
      [
        :prepare_vhdx_image_stemcell
      ]
    end

    def files_package_stages
      [
        :prepare_files_image_stemcell
      ]
    end
  end
end
# rubocop:enable Metrics/ClassLength
