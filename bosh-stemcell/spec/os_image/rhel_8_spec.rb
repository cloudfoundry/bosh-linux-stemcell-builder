require 'spec_helper'

describe 'RHEL 8 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an os with chrony'
  it_behaves_like 'a CentOS or RHEL based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_rhel' do
    describe command('rct cat-cert /etc/pki/product/69.pem') do
      its (:stdout) { should match /rhel-8/ }
    end

    describe file('/etc/os-release') do
      # SEE: https://www.freedesktop.org/software/systemd/man/os-release.html
      it { should be_file }
      its(:content) { should include ('ID="rhel"')}
      its(:content) { should include ('NAME="Red Hat Enterprise Linux"')}
      its(:content) { should include ('VERSION_ID="8')} # example: `VERSION_ID="8.5"`
      its(:content) { should include ('VERSION="8')} # example: `VERSION="8.5 (Ootpa)"`
      its(:content) { should include ('PRETTY_NAME="Red Hat Enterprise Linux 8.')} # example: `PRETTY_NAME="Red Hat Enterprise Linux 8.5 (Ootpa)"`
    end

    describe file('/etc/redhat-release') do
      # NOTE: This file MUST exist, or else the automation will mis-identify the OS-type of this stemcell.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      it { should be_file }
      its(:content) { should match (/Red Hat Enterprise Linux release 8\./)}
    end

    describe file('/etc/centos-release') do
      # NOTE: The stemcell builder automation infers the OS-type based on the existence of specific `/etc/*-release` files,
      # so this file MUST NOT exist in this stemcell,
      # or else the automation will incorrectly identify this stemcell as a CentOS stemcell.
      # NOTE: It is NOT OK for both this file and the one above to both exist (for RHEL stemcells),
      # since the OS-type-inference code gives higher precedence to this file.
      # SEE: `function get_os_type` at stemcell_builder/lib/prelude_apply.bash:22-48
      it { should_not be_file }
    end

    %w(
      redhat-release
      epel-release
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'installed by base_centos_packages' do
    # explicitly installed packages. see: stemcell_builder/stages/base_centos_packages/apply.sh
    %w(
      bind
      bind-utils
      bison
      bzip2-devel
      cloud-utils-growpart
      cmake
      curl
      dhcp-client
      e2fsprogs
      flex
      gdb
      gdisk
      iptables
      iputils
      libaio
      libcap
      libcap-devel
      libcurl
      libcurl-devel
      libuuid-devel
      libxml2
      libxml2-devel
      libxslt
      libxslt-devel
      libyaml-devel
      lsof
      ncurses-devel
      network-scripts
      NetworkManager
      nmap-ncat
      nvme-cli
      openssh-server
      openssl-devel
      parted
      psmisc
      readline-devel
      rsync
      strace
      sudo
      sysstat
      tcpdump
      traceroute
      unzip
      wget
      xfsprogs
      zip
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    # implicitly installed packages.
    %w(
      cronie-anacron
      glibc-static
      openssl
      quota
      rpm-build
      rpmdevtools
      rsyslog
      rsyslog-relp
      rsyslog-gnutls
      rsyslog-mmjsonparse
      runit
      systemd
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'ctrl-alt-del restrictions' do
    context 'overriding control alt delete burst action (stig: V-230531)' do
      describe file('/etc/systemd/system.conf') do
        it { should be_file }
        its(:content) { should match /^CtrlAltDelBurstAction=none$/ }
      end
    end
  end

  context 'installed by image_install_grub' do
    context 'required initramfs modules' do
      describe command("/usr/lib/dracut/skipcpio /boot/initramfs-4.18.*.x86_64.img | zcat | cpio -t | grep '/lib/modules/4.18.*.x86_64'") do

        # SEE: RHEL 8 adoption: 11.1. Removed hardware support: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/considerations_in_adopting_rhel_8/hardware-enablement_considerations-in-adopting-rhel-8#removed-hardware-support_hardware-enablement
        modules = %w(
          extra/kmod-kvdo/uds/uds.ko
          extra/kmod-kvdo/vdo/kvdo.ko
          kernel/arch/x86/crypto/blowfish-x86_64.ko.xz
          kernel/arch/x86/crypto/camellia-aesni-avx-x86_64.ko.xz
          kernel/arch/x86/crypto/camellia-aesni-avx2.ko.xz
          kernel/arch/x86/crypto/camellia-x86_64.ko.xz
          kernel/arch/x86/crypto/cast5-avx-x86_64.ko.xz
          kernel/arch/x86/crypto/cast6-avx-x86_64.ko.xz
          kernel/arch/x86/crypto/chacha20-x86_64.ko.xz
          kernel/arch/x86/crypto/crc32-pclmul.ko.xz
          kernel/arch/x86/crypto/crc32c-intel.ko.xz
          kernel/arch/x86/crypto/crct10dif-pclmul.ko.xz
          kernel/arch/x86/crypto/des3_ede-x86_64.ko.xz
          kernel/arch/x86/crypto/ghash-clmulni-intel.ko.xz
          kernel/arch/x86/crypto/poly1305-x86_64.ko.xz
          kernel/arch/x86/crypto/serpent-avx-x86_64.ko.xz
          kernel/arch/x86/crypto/serpent-avx2.ko.xz
          kernel/arch/x86/crypto/serpent-sse2-x86_64.ko.xz
          kernel/arch/x86/crypto/sha1-mb/sha1-mb.ko.xz
          kernel/arch/x86/crypto/sha256-mb/sha256-mb.ko.xz
          kernel/arch/x86/crypto/sha512-mb/sha512-mb.ko.xz
          kernel/arch/x86/crypto/twofish-avx-x86_64.ko.xz
          kernel/arch/x86/crypto/twofish-x86_64-3way.ko.xz
          kernel/arch/x86/crypto/twofish-x86_64.ko.xz
          kernel/block/t10-pi.ko.xz
          kernel/crypto/ansi_cprng.ko.xz
          kernel/crypto/anubis.ko.xz
          kernel/crypto/arc4.ko.xz
          kernel/crypto/async_tx/async_memcpy.ko.xz
          kernel/crypto/async_tx/async_pq.ko.xz
          kernel/crypto/async_tx/async_raid6_recov.ko.xz
          kernel/crypto/async_tx/async_tx.ko.xz
          kernel/crypto/async_tx/async_xor.ko.xz
          kernel/crypto/async_tx/raid6test.ko.xz
          kernel/crypto/blowfish_common.ko.xz
          kernel/crypto/blowfish_generic.ko.xz
          kernel/crypto/camellia_generic.ko.xz
          kernel/crypto/cast5_generic.ko.xz
          kernel/crypto/cast6_generic.ko.xz
          kernel/crypto/cast_common.ko.xz
          kernel/crypto/ccm.ko.xz
          kernel/crypto/chacha20_generic.ko.xz
          kernel/crypto/chacha20poly1305.ko.xz
          kernel/crypto/cmac.ko.xz
          kernel/crypto/crc32_generic.ko.xz
          kernel/crypto/crypto_user.ko.xz
          kernel/crypto/des_generic.ko.xz
          kernel/crypto/dh_generic.ko.xz
          kernel/crypto/ecdh_generic.ko.xz
          kernel/crypto/echainiv.ko.xz
          kernel/crypto/fcrypt.ko.xz
          kernel/crypto/khazad.ko.xz
          kernel/crypto/lrw.ko.xz
          kernel/crypto/mcryptd.ko.xz
          kernel/crypto/md4.ko.xz
          kernel/crypto/michael_mic.ko.xz
          kernel/crypto/pcbc.ko.xz
          kernel/crypto/pcrypt.ko.xz
          kernel/crypto/poly1305_generic.ko.xz
          kernel/crypto/rmd128.ko.xz
          kernel/crypto/rmd160.ko.xz
          kernel/crypto/rmd256.ko.xz
          kernel/crypto/rmd320.ko.xz
          kernel/crypto/salsa20_generic.ko.xz
          kernel/crypto/seed.ko.xz
          kernel/crypto/seqiv.ko.xz
          kernel/crypto/serpent_generic.ko.xz
          kernel/crypto/sha3_generic.ko.xz
          kernel/crypto/tcrypt.ko.xz
          kernel/crypto/tea.ko.xz
          kernel/crypto/tgr192.ko.xz
          kernel/crypto/twofish_common.ko.xz
          kernel/crypto/twofish_generic.ko.xz
          kernel/crypto/vmac.ko.xz
          kernel/crypto/wp512.ko.xz
          kernel/crypto/xcbc.ko.xz
          kernel/crypto/xor.ko.xz
          kernel/crypto/xts.ko.xz
          kernel/drivers/acpi/nfit/nfit.ko.xz
          kernel/drivers/ata/ahci.ko.xz
          kernel/drivers/ata/ahci_platform.ko.xz
          kernel/drivers/ata/ata_generic.ko.xz
          kernel/drivers/ata/ata_piix.ko.xz
          kernel/drivers/ata/libahci.ko.xz
          kernel/drivers/ata/libahci_platform.ko.xz
          kernel/drivers/ata/libata.ko.xz
          kernel/drivers/block/brd.ko.xz
          kernel/drivers/block/loop.ko.xz
          kernel/drivers/block/nbd.ko.xz
          kernel/drivers/block/null_blk.ko.xz
          kernel/drivers/block/pktcdvd.ko.xz
          kernel/drivers/block/rbd.ko.xz
          kernel/drivers/block/virtio_blk.ko.xz
          kernel/drivers/block/xen-blkfront.ko.xz
          kernel/drivers/block/zram/zram.ko.xz
          kernel/drivers/cdrom/cdrom.ko.xz
          kernel/drivers/char/virtio_console.ko.xz
          kernel/drivers/crypto/cavium/nitrox/n5pf.ko.xz
          kernel/drivers/crypto/ccp/ccp-crypto.ko.xz
          kernel/drivers/crypto/ccp/ccp.ko.xz
          kernel/drivers/crypto/padlock-aes.ko.xz
          kernel/drivers/crypto/padlock-sha.ko.xz
          kernel/drivers/crypto/qat/qat_4xxx/qat_4xxx.ko.xz
          kernel/drivers/crypto/qat/qat_c3xxx/qat_c3xxx.ko.xz
          kernel/drivers/crypto/qat/qat_c3xxxvf/qat_c3xxxvf.ko.xz
          kernel/drivers/crypto/qat/qat_c62x/qat_c62x.ko.xz
          kernel/drivers/crypto/qat/qat_c62xvf/qat_c62xvf.ko.xz
          kernel/drivers/crypto/qat/qat_common/intel_qat.ko.xz
          kernel/drivers/crypto/qat/qat_dh895xcc/qat_dh895xcc.ko.xz
          kernel/drivers/crypto/qat/qat_dh895xccvf/qat_dh895xccvf.ko.xz
          kernel/drivers/dca/dca.ko.xz
          kernel/drivers/hid/hid-a4tech.ko.xz
          kernel/drivers/hid/hid-alps.ko.xz
          kernel/drivers/hid/hid-apple.ko.xz
          kernel/drivers/hid/hid-appleir.ko.xz
          kernel/drivers/hid/hid-asus.ko.xz
          kernel/drivers/hid/hid-aureal.ko.xz
          kernel/drivers/hid/hid-axff.ko.xz
          kernel/drivers/hid/hid-belkin.ko.xz
          kernel/drivers/hid/hid-betopff.ko.xz
          kernel/drivers/hid/hid-cherry.ko.xz
          kernel/drivers/hid/hid-chicony.ko.xz
          kernel/drivers/hid/hid-cmedia.ko.xz
          kernel/drivers/hid/hid-corsair.ko.xz
          kernel/drivers/hid/hid-cypress.ko.xz
          kernel/drivers/hid/hid-dr.ko.xz
          kernel/drivers/hid/hid-elan.ko.xz
          kernel/drivers/hid/hid-elecom.ko.xz
          kernel/drivers/hid/hid-elo.ko.xz
          kernel/drivers/hid/hid-ezkey.ko.xz
          kernel/drivers/hid/hid-gaff.ko.xz
          kernel/drivers/hid/hid-gembird.ko.xz
          kernel/drivers/hid/hid-gfrm.ko.xz
          kernel/drivers/hid/hid-gt683r.ko.xz
          kernel/drivers/hid/hid-gyration.ko.xz
          kernel/drivers/hid/hid-holtek-kbd.ko.xz
          kernel/drivers/hid/hid-holtek-mouse.ko.xz
          kernel/drivers/hid/hid-holtekff.ko.xz
          kernel/drivers/hid/hid-hyperv.ko.xz
          kernel/drivers/hid/hid-icade.ko.xz
          kernel/drivers/hid/hid-ite.ko.xz
          kernel/drivers/hid/hid-jabra.ko.xz
          kernel/drivers/hid/hid-kensington.ko.xz
          kernel/drivers/hid/hid-keytouch.ko.xz
          kernel/drivers/hid/hid-kye.ko.xz
          kernel/drivers/hid/hid-lcpower.ko.xz
          kernel/drivers/hid/hid-led.ko.xz
          kernel/drivers/hid/hid-lenovo.ko.xz
          kernel/drivers/hid/hid-lg-g15.ko.xz
          kernel/drivers/hid/hid-logitech-dj.ko.xz
          kernel/drivers/hid/hid-logitech-hidpp.ko.xz
          kernel/drivers/hid/hid-logitech.ko.xz
          kernel/drivers/hid/hid-microsoft.ko.xz
          kernel/drivers/hid/hid-monterey.ko.xz
          kernel/drivers/hid/hid-multitouch.ko.xz
          kernel/drivers/hid/hid-nti.ko.xz
          kernel/drivers/hid/hid-ortek.ko.xz
          kernel/drivers/hid/hid-penmount.ko.xz
          kernel/drivers/hid/hid-petalynx.ko.xz
          kernel/drivers/hid/hid-pl.ko.xz
          kernel/drivers/hid/hid-plantronics.ko.xz
          kernel/drivers/hid/hid-primax.ko.xz
          kernel/drivers/hid/hid-rmi.ko.xz
          kernel/drivers/hid/hid-roccat-arvo.ko.xz
          kernel/drivers/hid/hid-roccat-common.ko.xz
          kernel/drivers/hid/hid-roccat-isku.ko.xz
          kernel/drivers/hid/hid-roccat-kone.ko.xz
          kernel/drivers/hid/hid-roccat-koneplus.ko.xz
          kernel/drivers/hid/hid-roccat-konepure.ko.xz
          kernel/drivers/hid/hid-roccat-kovaplus.ko.xz
          kernel/drivers/hid/hid-roccat-lua.ko.xz
          kernel/drivers/hid/hid-roccat-pyra.ko.xz
          kernel/drivers/hid/hid-roccat-ryos.ko.xz
          kernel/drivers/hid/hid-roccat-savu.ko.xz
          kernel/drivers/hid/hid-roccat.ko.xz
          kernel/drivers/hid/hid-saitek.ko.xz
          kernel/drivers/hid/hid-samsung.ko.xz
          kernel/drivers/hid/hid-sensor-custom.ko.xz
          kernel/drivers/hid/hid-sjoy.ko.xz
          kernel/drivers/hid/hid-sony.ko.xz
          kernel/drivers/hid/hid-speedlink.ko.xz
          kernel/drivers/hid/hid-steelseries.ko.xz
          kernel/drivers/hid/hid-sunplus.ko.xz
          kernel/drivers/hid/hid-tivo.ko.xz
          kernel/drivers/hid/hid-tmff.ko.xz
          kernel/drivers/hid/hid-topseed.ko.xz
          kernel/drivers/hid/hid-twinhan.ko.xz
          kernel/drivers/hid/hid-uclogic.ko.xz
          kernel/drivers/hid/hid-waltop.ko.xz
          kernel/drivers/hid/hid-wiimote.ko.xz
          kernel/drivers/hid/hid-xinmo.ko.xz
          kernel/drivers/hid/hid-zpff.ko.xz
          kernel/drivers/hid/hid-zydacron.ko.xz
          kernel/drivers/hid/i2c-hid/i2c-hid.ko.xz
          kernel/drivers/hid/intel-ish-hid/intel-ish-ipc.ko.xz
          kernel/drivers/hid/intel-ish-hid/intel-ishtp-hid.ko.xz
          kernel/drivers/hid/intel-ish-hid/intel-ishtp.ko.xz
          kernel/drivers/hid/uhid.ko.xz
          kernel/drivers/hid/wacom.ko.xz
          kernel/drivers/hv/hv_vmbus.ko.xz
          kernel/drivers/i2c/algos/i2c-algo-bit.ko.xz
          kernel/drivers/input/ff-memless.ko.xz
          kernel/drivers/input/rmi4/rmi_core.ko.xz
          kernel/drivers/input/serio/altera_ps2.ko.xz
          kernel/drivers/input/serio/arc_ps2.ko.xz
          kernel/drivers/input/serio/hyperv-keyboard.ko.xz
          kernel/drivers/input/serio/serio_raw.ko.xz
          kernel/drivers/md/dm-bio-prison.ko.xz
          kernel/drivers/md/dm-bufio.ko.xz
          kernel/drivers/md/dm-cache-smq.ko.xz
          kernel/drivers/md/dm-cache.ko.xz
          kernel/drivers/md/dm-crypt.ko.xz
          kernel/drivers/md/dm-delay.ko.xz
          kernel/drivers/md/dm-era.ko.xz
          kernel/drivers/md/dm-flakey.ko.xz
          kernel/drivers/md/dm-historical-service-time.ko.xz
          kernel/drivers/md/dm-integrity.ko.xz
          kernel/drivers/md/dm-io-affinity.ko.xz
          kernel/drivers/md/dm-log-userspace.ko.xz
          kernel/drivers/md/dm-log-writes.ko.xz
          kernel/drivers/md/dm-log.ko.xz
          kernel/drivers/md/dm-mirror.ko.xz
          kernel/drivers/md/dm-mod.ko.xz
          kernel/drivers/md/dm-multipath.ko.xz
          kernel/drivers/md/dm-queue-length.ko.xz
          kernel/drivers/md/dm-raid.ko.xz
          kernel/drivers/md/dm-region-hash.ko.xz
          kernel/drivers/md/dm-round-robin.ko.xz
          kernel/drivers/md/dm-service-time.ko.xz
          kernel/drivers/md/dm-snapshot.ko.xz
          kernel/drivers/md/dm-switch.ko.xz
          kernel/drivers/md/dm-thin-pool.ko.xz
          kernel/drivers/md/dm-verity.ko.xz
          kernel/drivers/md/dm-writecache.ko.xz
          kernel/drivers/md/dm-zero.ko.xz
          kernel/drivers/md/faulty.ko.xz
          kernel/drivers/md/linear.ko.xz
          kernel/drivers/md/md-cluster.ko.xz
          kernel/drivers/md/persistent-data/dm-persistent-data.ko.xz
          kernel/drivers/md/raid0.ko.xz
          kernel/drivers/md/raid1.ko.xz
          kernel/drivers/md/raid10.ko.xz
          kernel/drivers/md/raid456.ko.xz
          kernel/drivers/message/fusion/mptbase.ko.xz
          kernel/drivers/message/fusion/mptsas.ko.xz
          kernel/drivers/message/fusion/mptscsih.ko.xz
          kernel/drivers/message/fusion/mptspi.ko.xz
          kernel/drivers/net/bonding/bonding.ko.xz
          kernel/drivers/net/ethernet/amazon/ena/ena.ko.xz
          kernel/drivers/net/ethernet/cavium/liquidio/liquidio.ko.xz
          kernel/drivers/net/ethernet/cavium/liquidio/liquidio_vf.ko.xz
          kernel/drivers/net/ethernet/dnet.ko.xz
          kernel/drivers/net/ethernet/ethoc.ko.xz
          kernel/drivers/net/ethernet/google/gve/gve.ko.xz
          kernel/drivers/net/ethernet/huawei/hinic/hinic.ko.xz
          kernel/drivers/net/ethernet/intel/e1000/e1000.ko.xz
          kernel/drivers/net/ethernet/intel/e1000e/e1000e.ko.xz
          kernel/drivers/net/ethernet/intel/fm10k/fm10k.ko.xz
          kernel/drivers/net/ethernet/intel/i40e/i40e.ko.xz
          kernel/drivers/net/ethernet/intel/iavf/iavf.ko.xz
          kernel/drivers/net/ethernet/intel/ice/ice.ko.xz
          kernel/drivers/net/ethernet/intel/igb/igb.ko.xz
          kernel/drivers/net/ethernet/intel/igbvf/igbvf.ko.xz
          kernel/drivers/net/ethernet/intel/igc/igc.ko.xz
          kernel/drivers/net/ethernet/intel/ixgbe/ixgbe.ko.xz
          kernel/drivers/net/ethernet/intel/ixgbevf/ixgbevf.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlx4/mlx4_core.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlx4/mlx4_en.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlx5/core/mlx5_core.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxfw/mlxfw.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_core.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_i2c.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_minimal.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_pci.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_spectrum.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_switchib.ko.xz
          kernel/drivers/net/ethernet/mellanox/mlxsw/mlxsw_switchx2.ko.xz
          kernel/drivers/net/ethernet/microsoft/mana/mana.ko.xz
          kernel/drivers/net/ethernet/myricom/myri10ge/myri10ge.ko.xz
          kernel/drivers/net/ethernet/netronome/nfp/nfp.ko.xz
          kernel/drivers/net/ethernet/pensando/ionic/ionic.ko.xz
          kernel/drivers/net/ethernet/realtek/8139cp.ko.xz
          kernel/drivers/net/ethernet/realtek/8139too.ko.xz
          kernel/drivers/net/ethernet/realtek/r8169.ko.xz
          kernel/drivers/net/fjes/fjes.ko.xz
          kernel/drivers/net/geneve.ko.xz
          kernel/drivers/net/hyperv/hv_netvsc.ko.xz
          kernel/drivers/net/ipvlan/ipvlan.ko.xz
          kernel/drivers/net/macsec.ko.xz
          kernel/drivers/net/macvlan.ko.xz
          kernel/drivers/net/mdio.ko.xz
          kernel/drivers/net/mii.ko.xz
          kernel/drivers/net/net_failover.ko.xz
          kernel/drivers/net/phy/amd.ko.xz
          kernel/drivers/net/phy/aquantia.ko.xz
          kernel/drivers/net/phy/bcm-phy-lib.ko.xz
          kernel/drivers/net/phy/bcm7xxx.ko.xz
          kernel/drivers/net/phy/bcm87xx.ko.xz
          kernel/drivers/net/phy/broadcom.ko.xz
          kernel/drivers/net/phy/cicada.ko.xz
          kernel/drivers/net/phy/cortina.ko.xz
          kernel/drivers/net/phy/davicom.ko.xz
          kernel/drivers/net/phy/dp83640.ko.xz
          kernel/drivers/net/phy/dp83822.ko.xz
          kernel/drivers/net/phy/dp83848.ko.xz
          kernel/drivers/net/phy/dp83867.ko.xz
          kernel/drivers/net/phy/dp83tc811.ko.xz
          kernel/drivers/net/phy/et1011c.ko.xz
          kernel/drivers/net/phy/icplus.ko.xz
          kernel/drivers/net/phy/intel-xway.ko.xz
          kernel/drivers/net/phy/lxt.ko.xz
          kernel/drivers/net/phy/marvell.ko.xz
          kernel/drivers/net/phy/marvell10g.ko.xz
          kernel/drivers/net/phy/mdio-bcm-unimac.ko.xz
          kernel/drivers/net/phy/mdio-bitbang.ko.xz
          kernel/drivers/net/phy/mdio-cavium.ko.xz
          kernel/drivers/net/phy/mdio-mscc-miim.ko.xz
          kernel/drivers/net/phy/mdio-thunder.ko.xz
          kernel/drivers/net/phy/micrel.ko.xz
          kernel/drivers/net/phy/microchip.ko.xz
          kernel/drivers/net/phy/microchip_t1.ko.xz
          kernel/drivers/net/phy/mscc.ko.xz
          kernel/drivers/net/phy/national.ko.xz
          kernel/drivers/net/phy/phylink.ko.xz
          kernel/drivers/net/phy/qsemi.ko.xz
          kernel/drivers/net/phy/realtek.ko.xz
          kernel/drivers/net/phy/rockchip.ko.xz
          kernel/drivers/net/phy/smsc.ko.xz
          kernel/drivers/net/phy/spi_ks8995.ko.xz
          kernel/drivers/net/phy/ste10Xp.ko.xz
          kernel/drivers/net/phy/teranetics.ko.xz
          kernel/drivers/net/phy/uPD60620.ko.xz
          kernel/drivers/net/phy/vitesse.ko.xz
          kernel/drivers/net/phy/xilinx_gmii2rgmii.ko.xz
          kernel/drivers/net/team/team.ko.xz
          kernel/drivers/net/team/team_mode_activebackup.ko.xz
          kernel/drivers/net/team/team_mode_broadcast.ko.xz
          kernel/drivers/net/team/team_mode_loadbalance.ko.xz
          kernel/drivers/net/team/team_mode_random.ko.xz
          kernel/drivers/net/team/team_mode_roundrobin.ko.xz
          kernel/drivers/net/thunderbolt-net.ko.xz
          kernel/drivers/net/tun.ko.xz
          kernel/drivers/net/veth.ko.xz
          kernel/drivers/net/virtio_net.ko.xz
          kernel/drivers/net/vmxnet3/vmxnet3.ko.xz
          kernel/drivers/net/vrf.ko.xz
          kernel/drivers/net/vxlan.ko.xz
          kernel/drivers/net/wan/hdlc.ko.xz
          kernel/drivers/net/wan/hdlc_fr.ko.xz
          kernel/drivers/net/xen-netfront.ko.xz
          kernel/drivers/nvdimm/libnvdimm.ko.xz
          kernel/drivers/nvdimm/nd_blk.ko.xz
          kernel/drivers/nvdimm/nd_btt.ko.xz
          kernel/drivers/nvdimm/nd_pmem.ko.xz
          kernel/drivers/nvme/host/nvme-core.ko.xz
          kernel/drivers/nvme/host/nvme-fabrics.ko.xz
          kernel/drivers/nvme/host/nvme-fc.ko.xz
          kernel/drivers/nvme/host/nvme-tcp.ko.xz
          kernel/drivers/nvme/host/nvme.ko.xz
          kernel/drivers/nvme/target/nvme-loop.ko.xz
          kernel/drivers/nvme/target/nvmet.ko.xz
          kernel/drivers/pci/controller/pci-hyperv-intf.ko.xz
          kernel/drivers/pci/controller/pci-hyperv.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-alderlake.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-broxton.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-cannonlake.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-cedarfork.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-denverton.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-elkhartlake.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-emmitsburg.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-geminilake.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-icelake.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-lewisburg.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-sunrisepoint.ko.xz
          kernel/drivers/pinctrl/intel/pinctrl-tigerlake.ko.xz
          kernel/drivers/scsi/hpsa.ko.xz
          kernel/drivers/scsi/hv_storvsc.ko.xz
          kernel/drivers/scsi/libiscsi.ko.xz
          kernel/drivers/scsi/mpi3mr/mpi3mr.ko.xz
          kernel/drivers/scsi/scsi_debug.ko.xz
          kernel/drivers/scsi/scsi_transport_fc.ko.xz
          kernel/drivers/scsi/scsi_transport_iscsi.ko.xz
          kernel/drivers/scsi/scsi_transport_sas.ko.xz
          kernel/drivers/scsi/scsi_transport_spi.ko.xz
          kernel/drivers/scsi/sd_mod.ko.xz
          kernel/drivers/scsi/sg.ko.xz
          kernel/drivers/scsi/smartpqi/smartpqi.ko.xz
          kernel/drivers/scsi/sr_mod.ko.xz
          kernel/drivers/scsi/virtio_scsi.ko.xz
          kernel/drivers/scsi/vmw_pvscsi.ko.xz
          kernel/drivers/target/iscsi/iscsi_target_mod.ko.xz
          kernel/drivers/target/loopback/tcm_loop.ko.xz
          kernel/drivers/target/target_core_file.ko.xz
          kernel/drivers/target/target_core_iblock.ko.xz
          kernel/drivers/target/target_core_mod.ko.xz
          kernel/drivers/target/target_core_pscsi.ko.xz
          kernel/drivers/usb/storage/uas.ko.xz
          kernel/drivers/usb/storage/ums-alauda.ko.xz
          kernel/drivers/usb/storage/ums-cypress.ko.xz
          kernel/drivers/usb/storage/ums-datafab.ko.xz
          kernel/drivers/usb/storage/ums-eneub6250.ko.xz
          kernel/drivers/usb/storage/ums-freecom.ko.xz
          kernel/drivers/usb/storage/ums-isd200.ko.xz
          kernel/drivers/usb/storage/ums-jumpshot.ko.xz
          kernel/drivers/usb/storage/ums-karma.ko.xz
          kernel/drivers/usb/storage/ums-onetouch.ko.xz
          kernel/drivers/usb/storage/ums-realtek.ko.xz
          kernel/drivers/usb/storage/ums-sddr09.ko.xz
          kernel/drivers/usb/storage/ums-sddr55.ko.xz
          kernel/drivers/usb/storage/ums-usbat.ko.xz
          kernel/drivers/usb/storage/usb-storage.ko.xz
          kernel/drivers/vdpa/vdpa.ko.xz
          kernel/drivers/virtio/virtio_vdpa.ko.xz
          kernel/fs/binfmt_misc.ko.xz
          kernel/fs/cachefiles/cachefiles.ko.xz
          kernel/fs/ceph/ceph.ko.xz
          kernel/fs/dlm/dlm.ko.xz
          kernel/fs/ext4/ext4.ko.xz
          kernel/fs/fat/fat.ko.xz
          kernel/fs/fat/msdos.ko.xz
          kernel/fs/fat/vfat.ko.xz
          kernel/fs/fscache/fscache.ko.xz
          kernel/fs/fuse/fuse.ko.xz
          kernel/fs/fuse/virtiofs.ko.xz
          kernel/fs/gfs2/gfs2.ko.xz
          kernel/fs/isofs/isofs.ko.xz
          kernel/fs/jbd2/jbd2.ko.xz
          kernel/fs/mbcache.ko.xz
          kernel/fs/nfs_common/grace.ko.xz
          kernel/fs/nfs_common/nfs_acl.ko.xz
          kernel/fs/nls/mac-celtic.ko.xz
          kernel/fs/nls/mac-centeuro.ko.xz
          kernel/fs/nls/mac-croatian.ko.xz
          kernel/fs/nls/mac-cyrillic.ko.xz
          kernel/fs/nls/mac-gaelic.ko.xz
          kernel/fs/nls/mac-greek.ko.xz
          kernel/fs/nls/mac-iceland.ko.xz
          kernel/fs/nls/mac-inuit.ko.xz
          kernel/fs/nls/mac-roman.ko.xz
          kernel/fs/nls/mac-romanian.ko.xz
          kernel/fs/nls/mac-turkish.ko.xz
          kernel/fs/nls/nls_cp1250.ko.xz
          kernel/fs/nls/nls_cp1251.ko.xz
          kernel/fs/nls/nls_cp1255.ko.xz
          kernel/fs/nls/nls_cp737.ko.xz
          kernel/fs/nls/nls_cp775.ko.xz
          kernel/fs/nls/nls_cp850.ko.xz
          kernel/fs/nls/nls_cp852.ko.xz
          kernel/fs/nls/nls_cp855.ko.xz
          kernel/fs/nls/nls_cp857.ko.xz
          kernel/fs/nls/nls_cp860.ko.xz
          kernel/fs/nls/nls_cp861.ko.xz
          kernel/fs/nls/nls_cp862.ko.xz
          kernel/fs/nls/nls_cp863.ko.xz
          kernel/fs/nls/nls_cp864.ko.xz
          kernel/fs/nls/nls_cp865.ko.xz
          kernel/fs/nls/nls_cp866.ko.xz
          kernel/fs/nls/nls_cp869.ko.xz
          kernel/fs/nls/nls_cp874.ko.xz
          kernel/fs/nls/nls_cp932.ko.xz
          kernel/fs/nls/nls_cp936.ko.xz
          kernel/fs/nls/nls_cp949.ko.xz
          kernel/fs/nls/nls_cp950.ko.xz
          kernel/fs/nls/nls_euc-jp.ko.xz
          kernel/fs/nls/nls_iso8859-1.ko.xz
          kernel/fs/nls/nls_iso8859-13.ko.xz
          kernel/fs/nls/nls_iso8859-14.ko.xz
          kernel/fs/nls/nls_iso8859-15.ko.xz
          kernel/fs/nls/nls_iso8859-2.ko.xz
          kernel/fs/nls/nls_iso8859-3.ko.xz
          kernel/fs/nls/nls_iso8859-4.ko.xz
          kernel/fs/nls/nls_iso8859-5.ko.xz
          kernel/fs/nls/nls_iso8859-6.ko.xz
          kernel/fs/nls/nls_iso8859-7.ko.xz
          kernel/fs/nls/nls_iso8859-9.ko.xz
          kernel/fs/nls/nls_koi8-r.ko.xz
          kernel/fs/nls/nls_koi8-ru.ko.xz
          kernel/fs/nls/nls_koi8-u.ko.xz
          kernel/fs/nls/nls_utf8.ko.xz
          kernel/fs/overlayfs/overlay.ko.xz
          kernel/fs/pstore/ramoops.ko.xz
          kernel/fs/udf/udf.ko.xz
          kernel/fs/xfs/xfs.ko.xz
          kernel/lib/crc-itu-t.ko.xz
          kernel/lib/crypto/libarc4.ko.xz
          kernel/lib/libcrc32c.ko.xz
          kernel/lib/objagg.ko.xz
          kernel/lib/parman.ko.xz
          kernel/lib/raid6/raid6_pq.ko.xz
          kernel/lib/reed_solomon/reed_solomon.ko.xz
          kernel/net/802/garp.ko.xz
          kernel/net/802/mrp.ko.xz
          kernel/net/802/stp.ko.xz
          kernel/net/8021q/8021q.ko.xz
          kernel/net/bridge/bridge.ko.xz
          kernel/net/ceph/libceph.ko.xz
          kernel/net/core/failover.ko.xz
          kernel/net/dns_resolver/dns_resolver.ko.xz
          kernel/net/ipv4/udp_tunnel.ko.xz
          kernel/net/ipv6/ip6_tunnel.ko.xz
          kernel/net/ipv6/ip6_udp_tunnel.ko.xz
          kernel/net/ipv6/tunnel6.ko.xz
          kernel/net/llc/llc.ko.xz
          kernel/net/psample/psample.ko.xz
          kernel/net/sunrpc/sunrpc.ko.xz
          kernel/net/tls/tls.ko.xz
        )

        modules.each do |m|
          its (:stdout) { should include("/#{m}") }

          # NOTE: If we wanted to match the full module file paths, we could do something like the following
          # # SEE: RHEL release kernel versions: https://access.redhat.com/articles/3078
          # # NOTE: The `$(uname -r)` command should return the current kernel version, but not sure we can use that here.
          # kernel_version = '4\.18\..*\.el8\.x86_64' # should match: '4.18.0-348.el8.x86_64'
          # modules_dir = "usr/lib/modules/#{kernel_version}/"
          # its (:stdout) { should match("^#{modules_dir}#{module_file}$") }
        end
      end
    end
  end

  context 'official Red Hat gpg key is installed (stig: V-38476)' do
    describe command('rpm -qa gpg-pubkey* 2>/dev/null | xargs rpm -qi 2>/dev/null') do
      # SEE: https://access.redhat.com/security/team/key
      it('shows the Red Hat RHEL 6,7,8 release key is installed') { expect(subject.stdout).to include('Red Hat, Inc. (release key 2) <security@redhat.com>') }
      it('shows the Red Hat RHEL 8 disaster recovery key is installed') do
        # NOTE: The Red Hat docs page (see link above) says that the RHEL 8 disaster recovery key (published 2018-06-27)
        # should be named 'Red Hat, Inc. (auxiliary key 2) <security@redhat.com>'.
        # However, with RHEL 8.5 we find a key with matching publish date and fingerprint,
        # but with a different name/packager (which matches the documented name of the RHEL 5,6,7 gpg key).
        # Based on the matching publish date and fingerprint, we have changed the spec
        # to match the observed name plus the publish date (instead of the documented name).
        # See the commit message associated with this comment for details.
        expect(subject.stdout).to include('Red Hat, Inc. (auxiliary key) <security@redhat.com>')
        expect(subject.stdout).to include('Build Date  : Wed 27 Jun 2018 12:33:57 AM UTC')
      end

      # SEE: https://getfedora.org/security/
      # SEE: https://dl.fedoraproject.org/pub/epel/
      it('shows the Fedora EPEL 8 key is installed') { expect(subject.stdout).to include('Fedora EPEL (8) <epel@fedoraproject.org>') }
    end
  end

  context 'ensure auditd file permissions and ownership (stig: V-38663) (stig: V-38664) (stig: V-38665)' do
    [[0o755, '/usr/bin/auvirt'],
     [0o755, '/usr/bin/ausyscall'],
     [0o755, '/usr/bin/aulastlog'],
     [0o755, '/usr/bin/aulast'],
     [0o700, '/var/log/audit'],
     [0o755, '/sbin/aureport'],
     [0o755, '/sbin/auditd'],
     [0o750, '/sbin/autrace'],
     [0o755, '/sbin/ausearch'],
     [0o755, '/sbin/augenrules'],
     [0o755, '/sbin/auditctl'],
     [0o750, '/etc/audit'],
     [0o750, '/etc/audit/plugins.d'],
     [0o640, '/etc/audit/plugins.d/af_unix.conf'],
     [0o640, '/etc/audit/plugins.d/syslog.conf'],
     [0o750, '/etc/audit/rules.d'],
     [0o640, '/etc/audit/rules.d/audit.rules'],
     [0o640, '/etc/audit/auditd.conf'],
     [0o644, '/lib/systemd/system/auditd.service']].each do |tuple|
      describe file(tuple[1]) do
        its(:owner) { should eq('root') }
        its(:mode)  { should eq(tuple[0]) }
        its(:group) { should eq('root') }
      end
    end
  end

  describe 'allowed user accounts' do
    describe file('/etc/passwd') do
      passwd_match_raw = <<HERE
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
adm:x:3:4:adm:/var/adm:/sbin/nologin
lp:x:4:7:lp:/var/spool/lpd:/sbin/nologin
sync:x:5:0:sync:/sbin:/bin/sync
shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown
halt:x:7:0:halt:/sbin:/sbin/halt
mail:x:8:12:mail:/var/spool/mail:/sbin/nologin
operator:x:11:0:operator:/root:/sbin/nologin
games:x:12:100:games:/usr/games:/sbin/nologin
ftp:x:14:50:FTP User:/var/ftp:/sbin/nologin
nobody:x:65534:65534:Kernel Overflow User:/:/sbin/nologin
tss:x:59:59:Account used for TPM access:/dev/null:/sbin/nologin
dbus:x:81:81:System message bus:/:/sbin/nologin
systemd-coredump:x:999:997:systemd Core Dumper:/:/sbin/nologin
systemd-resolve:x:193:193:systemd Resolver:/:/sbin/nologin
polkitd:x:998:995:User for polkitd:/:/sbin/nologin
cockpit-ws:x:997:994:User for cockpit web service:/nonexisting:/sbin/nologin
cockpit-wsinstance:x:996:993:User for cockpit-ws instances:/nonexisting:/sbin/nologin
libstoragemgmt:x:995:992:daemon account for libstoragemgmt:/var/run/lsm:/sbin/nologin
setroubleshoot:x:994:991::/var/lib/setroubleshoot:/sbin/nologin
sssd:x:993:990:User for sssd:/:/sbin/nologin
chrony:x:992:989::/var/lib/chrony:/sbin/nologin
tcpdump:x:72:72::/:/sbin/nologin
pesign:x:991:987:Group for the pesign signing daemon:/var/run/pesign:/sbin/nologin
sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin
named:x:25:25:Named:/var/named:/bin/false
vcap:x:1000:1000:BOSH System User:/home/vcap:/bin/bash
syslog:x:990:985::/home/syslog:/sbin/nologin
HERE
      passwd_match_lines = passwd_match_raw.split(/\n+/)

      its(:content_as_lines) { should match_array(passwd_match_lines)}
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(passwd_match_lines), -> { "full content: '#{subject.content}'" } }
    end

    describe file('/etc/shadow') do
      shadow_match_raw = <<HERE
root:(.+):\\d{5}:0:99999:7:::
bin:\\*:\\d{5}:0:99999:7:::
daemon:\\*:\\d{5}:0:99999:7:::
adm:\\*:\\d{5}:0:99999:7:::
lp:\\*:\\d{5}:0:99999:7:::
sync:\\*:\\d{5}:0:99999:7:::
shutdown:\\*:\\d{5}:0:99999:7:::
halt:\\*:\\d{5}:0:99999:7:::
mail:\\*:\\d{5}:0:99999:7:::
operator:\\*:\\d{5}:0:99999:7:::
games:\\*:\\d{5}:0:99999:7:::
ftp:\\*:\\d{5}:0:99999:7:::
nobody:\\*:\\d{5}:0:99999:7:::
tss:!!:\\d{5}::::::
dbus:!!:\\d{5}::::::
systemd-coredump:!!:\\d{5}::::::
systemd-resolve:!!:\\d{5}::::::
polkitd:!!:\\d{5}::::::
libstoragemgmt:!!:\\d{5}::::::
cockpit-ws:!!:\\d{5}::::::
cockpit-wsinstance:!!:\\d{5}::::::
sssd:!!:\\d{5}::::::
chrony:!!:\\d{5}::::::
sshd:!!:\\d{5}::::::
named:!!:\\d{5}::::::
tcpdump:!!:\\d{5}::::::
pesign:!!:\\d{5}::::::
setroubleshoot:!!:\\d{5}::::::
vcap:(.+):\\d{5}:1:99999:7:::
syslog:!!:\\d{5}::::::
HERE

      shadow_match_lines = shadow_match_raw.split(/\n+/).map { |l| Regexp.new("^#{l}$") }
      its(:content_as_lines) { should match_array(shadow_match_lines) }
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(shadow_match_lines), -> { "full content: '#{subject.content}'" } }
    end

    describe file('/etc/group') do

      group_raw = <<HERE
root:x:0:
bin:x:1:
daemon:x:2:
sys:x:3:
adm:x:4:vcap
tty:x:5:
disk:x:6:
lp:x:7:
mem:x:8:
kmem:x:9:
wheel:x:10:vcap
cdrom:x:11:vcap
mail:x:12:
man:x:15:
dialout:x:18:vcap
floppy:x:19:vcap
games:x:20:
tape:x:33:
video:x:39:vcap
ftp:x:50:
lock:x:54:
audio:x:63:vcap
users:x:100:
nobody:x:65534:
tss:x:59:
dbus:x:81:
utmp:x:22:
utempter:x:35:
input:x:999:
kvm:x:36:
render:x:998:
systemd-journal:x:190:
systemd-coredump:x:997:
systemd-resolve:x:193:
printadmin:x:996:
polkitd:x:995:
cockpit-ws:x:994:
cockpit-wsinstance:x:993:
libstoragemgmt:x:992:
setroubleshoot:x:991:
sssd:x:990:
chrony:x:989:
tcpdump:x:72:
slocate:x:21:
stapusr:x:156:
stapsys:x:157:
stapdev:x:158:
ssh_keys:x:988:
pesign:x:987:
sshd:x:74:
named:x:25:
admin:x:986:vcap
vcap:x:1000:syslog
bosh_sshers:x:1001:vcap
bosh_sudoers:x:1002:
syslog:x:985:
HERE
      group_lines = group_raw.split(/\n+/)
      its(:content_as_lines) { should match_array(group_lines)}
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(group_lines), -> { "full content: '#{subject.content}'" } }
    end

    describe file('/etc/gshadow') do

      gshadow_raw = <<HERE
root:*::
bin:*::
daemon:*::
sys:*::
adm:*::vcap
tty:*::
disk:*::
lp:*::
mem:*::
kmem:*::
wheel:*::vcap
cdrom:*::vcap
mail:*::
man:*::
dialout:*::vcap
floppy:*::vcap
games:*::
tape:*::
video:*::vcap
ftp:*::
lock:*::
audio:*::vcap
users:*::
nobody:*::
tss:!::
dbus:!::
utmp:!::
utempter:!::
input:!::
kvm:!::
render:!::
systemd-journal:!::
systemd-coredump:!::
systemd-resolve:!::
polkitd:!::
libstoragemgmt:!::
printadmin:!::
cockpit-ws:!::
cockpit-wsinstance:!::
sssd:!::
chrony:!::
slocate:!::
ssh_keys:!::
sshd:!::
named:!::
tcpdump:!::
stapusr:!::
stapsys:!::
stapdev:!::
pesign:!::
setroubleshoot:!::
admin:!::vcap
vcap:!::syslog
bosh_sshers:!::vcap
bosh_sudoers:!::
syslog:!::
HERE

      gshadow_lines = gshadow_raw.split(/\n+/)
      its(:content_as_lines) { should match_array(gshadow_lines)}
      # NOTE: The following line is needed because rspec truncates the previous line's output upon failure
      its(:content_as_lines) { should match_array(gshadow_lines), -> { "full content: '#{subject.content}'" } }
    end
  end
end
