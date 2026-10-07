#!/usr/bin/env ruby
#
# Re-triages the kernel module list used by the system_kernel_modules stage.
#
# Usage: scripts/retriage_kernel_modules.rb [<ci_log> | <modules_dir>] [csv]
#
#   <ci_log>       output of a stemcell build that failed in remove_kernel_modules.sh
#                  (file, or "-"/omitted for stdin). Works on any machine, e.g.:
#                    pbpaste | scripts/retriage_kernel_modules.rb
#                    fly -t <target> watch -j <pipeline>/<job> -b <build> | scripts/retriage_kernel_modules.rb
#                  The failure prints a TRIAGE DATA block naming the CSV and holding
#                  the new modules plus the modules.dep/modules.softdep entries needed.
#   <modules_dir>  an unpacked /usr/lib/modules/<kernel-version> tree that has
#                  modules.dep (and optionally modules.softdep), e.g. extracted
#                  from linux-modules-<version>-generic and indexed with depmod:
#                    dpkg-deb -x linux-modules-*.deb root && ln -s usr/lib root/lib
#                    depmod -b root <version>
#                  Needs a case-sensitive filesystem, i.e. Linux.
#   [csv]          defaults to the CSV named in the CI log, or
#                  stemcell_builder/stages/system_kernel_modules/linux-generic.csv
#
# The CSV is rewritten in place:
#   1. Every module in <modules_dir> gets a row; rows for modules that are not
#      present are kept as-is.
#   2. RULES are matched against rel_path (without the leading "kernel/"); the
#      first match sets remove/category/reason. Rows no rule matches keep their
#      existing triage, so hand-triaged rows survive a re-run.
#   3. Every dependency (modules.dep and modules.softdep) of a remove=No module
#      is forced to remove=No.
#
# New modules that no rule matches are reported and must be triaged by hand
# (add a rule, or add the row to the CSV and re-run).

require "csv"
require "stringio"
require "zlib"

KEEP = "No"
REMOVE = "Yes"

HV = "Hypervisor Guest Drivers"
EMU = "Emulated Virtual Hardware"
PT = "SR-IOV & Passthrough Devices"
STOR = "Storage Stack"
FS = "Filesystems"
NFS = "Network Filesystems"
NET = "Container & Overlay Networking"
TC = "Traffic Control (tc)"
IPSEC = "IPsec, TLS & VPN"
NESTED = "Nested Virtualization & Userspace I/O"
CONSOLE = "VM Console (Display & Input)"
DEP = "Dependency of Retained Module"
UNUSED_DEP = "Unused Dependency"

FIELDS = %w[module_name rel_path remove category reason].freeze

# [pattern, remove, category, reason]; first match wins.
RULES = [
  # ---- removals that must win over broader keep rules below ----
  [%r{drivers/block/xen-blkback/|drivers/net/xen-netback/|drivers/xen/xen-pciback/|drivers/xen/xen-scsiback},
    REMOVE, "Hypervisor Host-Side Backends",
    "Xen dom0 (host) backend driver; stemcells only run as Xen guests (domU), which use the *front drivers."],
  [%r{drivers/hv/mshv},
    REMOVE, "Hypervisor Host-Side Backends",
    "Hyper-V root partition (host) interface; stemcells only run as Hyper-V/Azure guests."],
  [%r{drivers/vhost/(vhost_scsi|vhost_vdpa|vringh)|drivers/vdpa/|drivers/virtio/virtio_vdpa|drivers/vfio/pci/(virtio|mlx5|pds|qat|xe)/|drivers/vfio/mdev/|drivers/gpu/drm/i915/kvmgt},
    REMOVE, "Host Hypervisor Passthrough & vDPA",
    "Host-side vDPA / vendor VFIO variant / mediated device driver for exposing devices to nested guests; not needed in a stemcell guest."],
  [%r{drivers/net/caif/|net/caif/|drivers/rpmsg/},
    REMOVE, "Legacy / Obscure Network Protocols",
    "CAIF modem / remote processor messaging transport for SoC co-processors; no stemcell use."],
  [%r{lib/test_|lib/xz/xz_dec_test|notifier-error-inject|mm/hwpoison-inject|mce-inject|punit_atom_debug|scsi/scsi_debug|block/null_blk|i2c-slave-testunit|misc/dummy-irq|hwtracing/stm/dummy_stm|pps/generators/pps_gen-dummy|crypto/tcrypt|pkcs7_test_key|net/core/pktgen|drivers/net/netdevsim|block/zloop},
    REMOVE, "Test & Debug Modules",
    "Kernel self-test, fault-injection, benchmark or dummy device module; not for production use."],
  [%r{drivers/gpu/drm/bridge/},
    REMOVE, "Display Panels & Legacy Framebuffers",
    "DRM bridge chip (HDMI/DisplayPort transmitter) for embedded display hardware."],
  [%r{drivers/misc/altera-stapl/},
    REMOVE, "FPGA Controllers",
    "Altera FPGA JTAG/STAPL bitstream programmer."],
  [%r{drivers/i2c/busses/i2c-cros-ec-tunnel},
    REMOVE, "Consumer Laptop & Desktop Platform",
    "ChromeOS embedded controller I2C tunnel."],
  [%r{drivers/platform/x86/dell/},
    REMOVE, "Consumer Laptop & Desktop Platform",
    "Dell laptop/desktop/PowerEdge platform driver (ACPI/WMI hotkeys and sensors, SMBIOS/BIOS settings, " \
    "BIOS update, systems management); not present on cloud virtual machines."],
  [%r{drivers/mmc/},
    REMOVE, "Physical Memory & Storage Controllers",
    "SD/MMC card host controller; not present on cloud VMs."],
  [%r{drivers/watchdog/mena21_wdt},
    REMOVE, "Physical Motherboard Watchdogs",
    "MEN A21 physical watchdog."],
  [%r{net/sched/em_canid},
    REMOVE, "Legacy / Obscure Network Protocols",
    "tc ematch for CAN bus IDs; CAN is removed."],
  [%r{drivers/md/md-cluster|fs/dlm/},
    REMOVE, "Exotic / Untrusted Filesystems",
    "Clustered MD / distributed lock manager for shared-disk clusters (gfs2/ocfs2); not used on stemcells."],
  [%r{drivers/nvme/host/nvme-rdma|drivers/nvme/target/|drivers/block/rnbd/|net/9p/9pnet_rdma|net/sunrpc/xprtrdma/|drivers/infiniband/},
    REMOVE, "InfiniBand / RDMA",
    "RDMA transport or NVMe/RNBD target; stemcells do not use RDMA fabrics or act as block storage targets."],
  [%r{drivers/target/|drivers/scsi/qla2xxx/tcm_qla2xxx|drivers/scsi/elx/},
    REMOVE, "Storage Target / iSCSI Target",
    "SCSI target (LIO) fabric module; stemcells are storage initiators, not targets."],
  [%r{crypto/af_alg},
    REMOVE, "AF_ALG Userspace Crypto Sockets",
    "AF_ALG socket family core; the algif_* interfaces are removed (algif_aead is also disabled in apply.sh) to shrink unprivileged attack surface."],
  [%r{fs/smb/server/},
    REMOVE, "In-Kernel SMB / CIFS Server & Client",
    "In-kernel SMB server (ksmbd); stemcells are SMB clients only."],
  [%r{drivers/net/ethernet/broadcom/cnic|drivers/scsi/(bnx2i|bnx2fc|qedi|qedf|be2iscsi|cxgbi|qla4xxx|fcoe|libfc|fnic|csiostor|bfa)},
    REMOVE, "Physical SAS, RAID & FibreChannel",
    "Hardware iSCSI/FCoE offload for physical converged adapters; VMs use the software iscsi_tcp initiator."],
  [%r{drivers/block/(aoe|mtip32xx)/},
    REMOVE, "Physical Memory & Storage Controllers",
    "ATA-over-Ethernet / Micron PCIe SSD block driver for physical hardware."],
  [%r{drivers/firmware/efi/efi-pstore},
    KEEP, HV,
    "Persists kernel panic logs to EFI variables on UEFI VMs (read back by systemd-pstore)."],

  # ---- hypervisor guest drivers ----
  [%r{drivers/hv/|drivers/net/hyperv/|drivers/net/ethernet/microsoft/mana/|drivers/scsi/hv_storvsc|drivers/pci/controller/pci-hyperv|drivers/input/serio/hyperv-keyboard|drivers/hid/hid-hyperv|drivers/gpu/drm/hyperv/|net/vmw_vsock/hv_sock|drivers/uio/uio_hv_generic},
    KEEP, HV,
    "Microsoft Hyper-V / Azure guest driver."],
  [%r{drivers/misc/vmw_|drivers/net/vmxnet3/|drivers/scsi/vmw_pvscsi|drivers/gpu/drm/vmwgfx/|drivers/ptp/ptp_vmw|net/vmw_vsock/vmw_vsock_vmci},
    KEEP, HV,
    "VMware vSphere guest driver."],
  [%r{drivers/xen/|drivers/char/tpm/xen-tpmfront|drivers/scsi/xen-scsifront|drivers/pci/xen-pcifront|drivers/usb/host/xen-hcd|drivers/input/misc/xen-kbdfront|drivers/watchdog/xen_wdt|drivers/gpu/drm/xen/|drivers/video/fbdev/xen-fbfront|net/9p/9pnet_xen},
    KEEP, HV,
    "Xen guest (domU) frontend or guest userspace interface (Alibaba Cloud, CloudStack, older AWS)."],
  [%r{drivers/net/ethernet/amazon/ena/|drivers/virt/nitro_enclaves/|drivers/misc/nsm|drivers/ptp/ptp_vmclock},
    KEEP, HV,
    "AWS Nitro guest driver (ENA NIC, Nitro Enclaves, Nitro Secure Module, vmclock)."],
  [%r{drivers/net/ethernet/google/gve/|drivers/net/ethernet/intel/idpf/},
    KEEP, HV,
    "Google Cloud guest NIC (gVNIC / IDPF)."],
  [%r{drivers/virtio/|drivers/scsi/virtio_scsi|drivers/block/virtio_blk|drivers/net/virtio_net|drivers/char/hw_random/virtio-rng|drivers/crypto/virtio/|drivers/gpu/drm/virtio/|drivers/i2c/busses/i2c-virtio|drivers/nvdimm/(nd_virtio|virtio_pmem)|fs/fuse/virtiofs|net/9p/9pnet_virtio|net/vmw_vsock/},
    KEEP, HV,
    "VirtIO paravirtual guest driver (KVM/QEMU: OpenStack, GCP, and others)."],
  [%r{drivers/ptp/ptp_kvm|drivers/firmware/qemu_fw_cfg|drivers/cpuidle/cpuidle-haltpoll|drivers/misc/pvpanic/|drivers/virt/vmgenid},
    KEEP, HV,
    "KVM/QEMU guest integration (PTP clock, fw_cfg, haltpoll idle, pvpanic, VM generation ID)."],
  [%r{drivers/virt/coco/|drivers/char/tpm/tpm_svsm},
    KEEP, HV,
    "Confidential VM guest driver (AMD SEV-SNP / Intel TDX attestation, SVSM vTPM)."],
  [%r{drivers/virt/vboxguest/|fs/vboxsf/|drivers/gpu/drm/vboxvideo/},
    KEEP, HV,
    "VirtualBox guest driver (VirtualBox CPI)."],
  [%r{drivers/watchdog/(i6300esb|softdog)},
    KEEP, HV,
    "Watchdog offered to VMs (QEMU i6300esb) or software watchdog."],

  # ---- emulated virtual hardware ----
  [%r{drivers/message/fusion/(mptbase|mptscsih|mptspi|mptsas)},
    KEEP, EMU,
    "LSI Logic Fusion-MPT SCSI/SAS; vSphere \"lsilogic\" (stemcell default, see image_ovf_vmx) and \"lsisas1068\" virtual controllers."],
  [%r{drivers/scsi/BusLogic|drivers/scsi/sym53c8xx_2/|drivers/scsi/megaraid/megaraid_sas|drivers/scsi/mpt3sas/|drivers/scsi/scsi_transport_(spi|sas)|drivers/scsi/raid_class|drivers/ata/(ahci|libahci|pata_acpi)\.},
    KEEP, EMU,
    "SCSI/SATA controller emulated by vSphere or QEMU/KVM (BusLogic, LSI 53c895a, MegaRAID SAS, AHCI)."],
  [%r{drivers/net/ethernet/intel/(e1000|e1000e)/|drivers/net/ethernet/amd/pcnet32|drivers/net/ethernet/realtek/8139(cp|too)},
    KEEP, EMU,
    "NIC emulated by a hypervisor (vSphere e1000/e1000e/vlance, QEMU e1000/rtl8139)."],
  [%r{drivers/gpu/drm/tiny/(bochs|cirrus-qemu)|drivers/gpu/drm/qxl/},
    KEEP, CONSOLE,
    "QEMU/KVM virtual display adapter for the VM console."],
  [%r{drivers/input/mouse/psmouse|drivers/input/serio/serio_raw|drivers/hid/hid\.|drivers/hid/hid-generic|drivers/hid/usbhid/usbhid},
    KEEP, CONSOLE,
    "Generic PS/2 or USB HID input used by hypervisor consoles."],
  [%r{drivers/acpi/nfit/|drivers/nvdimm/(nd_pmem|nd_btt)|drivers/dax/(dax_pmem|device_dax|kmem)},
    KEEP, EMU,
    "Virtual persistent memory (vSphere vPMem, QEMU NVDIMM) via ACPI NFIT."],

  # ---- SR-IOV VFs and mainstream server NICs/HBAs used via PCI passthrough ----
  [%r{drivers/net/ethernet/intel/(iavf|ixgbevf|igbvf)/},
    KEEP, PT,
    "Intel SR-IOV virtual function NIC (OpenStack SR-IOV, AWS legacy enhanced networking)."],
  [%r{drivers/net/ethernet/mellanox/(mlx4|mlx5/core|mlxfw)/},
    KEEP, PT,
    "Mellanox ConnectX NIC; Azure Accelerated Networking VF and SR-IOV/passthrough."],
  [%r{drivers/net/ethernet/intel/(igb|ixgbe|i40e|ice|libeth|libie)/|drivers/net/ethernet/broadcom/(tg3|bnx2x/|bnxt/)},
    KEEP, PT,
    "Mainstream Intel/Broadcom server NIC (PF/VF) used via SR-IOV or PCI passthrough."],
  [%r{drivers/net/ethernet/},
    REMOVE, "Legacy / Physical NICs",
    "Physical Ethernet adapter that is neither emulated by a supported hypervisor nor a mainstream SR-IOV/passthrough NIC."],
  [%r{drivers/net/fddi/|drivers/net/arcnet/|drivers/net/hamradio/|drivers/net/wan/|drivers/net/plip/|drivers/net/slip/|drivers/net/ppp/|drivers/net/team/},
    REMOVE, "Legacy / Obscure Network Protocols",
    "Legacy link layer (FDDI, ARCnet, ham radio, WAN/HDLC, PPP/SLIP) or teamd driver; not used on stemcells."],
  [%r{drivers/message/fusion/},
    REMOVE, "Physical SAS, RAID & FibreChannel",
    "Fusion-MPT FibreChannel/LAN/ioctl add-on for physical adapters."],
  [%r{drivers/ata/},
    REMOVE, "Physical SAS, RAID & FibreChannel",
    "Physical PATA/SATA/SoC ATA controller; hypervisors emulate PIIX (built in) or AHCI."],

  # ---- storage stack ----
  [%r{drivers/scsi/(iscsi_tcp|libiscsi|libiscsi_tcp|iscsi_boot_sysfs|scsi_transport_iscsi)|drivers/firmware/iscsi_ibft|drivers/scsi/device_handler/},
    KEEP, STOR,
    "Software iSCSI initiator and multipath device handlers (persistent disks, Kubernetes CSI)."],
  [%r{drivers/scsi/},
    REMOVE, "Physical SAS, RAID & FibreChannel",
    "Physical SCSI/SAS/RAID host bus adapter, tape or enclosure driver; not presented to cloud VMs."],
  [%r{drivers/md/|drivers/nvme/|drivers/block/(brd|nbd|rbd|zram/|ublk_drv|drbd/)|block/(bfq|kyber-iosched)},
    KEEP, STOR,
    "Block storage stack: device-mapper/MD RAID, NVMe (PCIe/TCP/FC), network and RAM block devices, I/O schedulers."],

  # ---- filesystems ----
  [%r{fs/(xfs|btrfs|overlayfs|isofs|udf|autofs|erofs|quota)/|fs/fuse/cuse|fs/binfmt_misc|fs/nls/(nls_ascii|nls_iso8859-1|nls_utf8|nls_ucs2_utils)\.},
    KEEP, FS,
    "Local, container or install-media filesystem support."],
  [%r{fs/(nfs|nfs_common|lockd|nfsd|netfs|cachefiles|ceph|9p)/|fs/smb/(client|common)/|net/sunrpc/|net/ceph/|net/9p/(9pnet|9pnet_fd)\.},
    KEEP, NFS,
    "Network filesystem client/server and its RPC stack (NFS, SMB/CIFS, CephFS/RBD, 9p) used by volume services and Kubernetes CSI."],

  # ---- networking ----
  [%r{net/(802|llc)/(stp|garp|mrp|llc)\.|net/bridge/|net/8021q/|drivers/net/(bonding/|dummy|ifb|veth|macvlan|macvtap|tap\.|ipvlan/|vxlan/|geneve|vrf|netconsole)},
    KEEP, NET,
    "Bridge, VLAN, bonding and virtual/overlay interfaces used by Garden, Silk, Kubernetes CNIs and BOSH networking."],
  [%r{net/openvswitch/|net/nsh/|net/psample/},
    KEEP, NET,
    "Open vSwitch datapath (Antrea / NSX-T NCP CNIs) and its NSH/psample dependencies."],
  [%r{net/ipv4/(ip_gre|gre|ipip|ip_tunnel|tunnel4|udp_tunnel|fou)\.|net/ipv6/(ip6_gre|sit|ip6_tunnel|ip6_udp_tunnel|tunnel6|fou6)\.},
    KEEP, NET,
    "IP tunnelling (GRE, IPIP, SIT, FOU, UDP tunnels) used by CNIs such as Calico and by VPN/overlay releases."],
  [%r{net/ipv4/(tcp_\w+|inet_diag|tcp_diag|udp_diag|raw_diag)\.|net/(unix|netlink|packet)/\w*diag|net/mptcp/mptcp_diag|net/xdp/xsk_diag},
    KEEP, NET,
    "TCP congestion control or socket diagnostics (ss) support."],
  [%r{net/sched/|net/mpls/mpls_gso},
    KEEP, TC,
    "tc qdiscs, classifiers and actions used for bandwidth limiting (Silk), Cilium/Calico eBPF datapaths and netem fault injection."],
  [%r{net/mpls/},
    REMOVE, "Router Protocols & SDN Switches",
    "MPLS label switching router; not used on stemcells."],
  [%r{net/(xfrm|key|tls)/|net/ipv4/(esp4|esp4_offload|ah4|ipcomp|xfrm4_tunnel|ip_vti)\.|net/ipv6/(esp6|esp6_offload|ah6|ipcomp6|xfrm6_tunnel|ip6_vti|mip6)\.|drivers/net/(wireguard|ovpn|macsec)},
    KEEP, IPSEC,
    "IPsec/XFRM, kernel TLS, WireGuard, OpenVPN DCO and MACsec."],
  [%r{net/(netfilter|ipv4/netfilter|ipv6/netfilter|bridge/netfilter)/},
    KEEP, "Netfilter & Firewall",
    "Netfilter / iptables / nftables / IPVS module used for BOSH firewalling, container NAT and Kubernetes service proxying."],

  # ---- nested virtualization / userspace I/O ----
  [%r{arch/x86/kvm/|virt/lib/irqbypass|drivers/vhost/(vhost|vhost_net|vhost_vsock|vhost_iotlb)\.|drivers/vfio/(vfio|vfio_iommu_type1|pci/vfio-pci|pci/vfio-pci-core)\.|drivers/iommu/iommufd/|drivers/uio/(uio|uio_pci_generic)\.|drivers/pci/pci-stub},
    KEEP, NESTED,
    "KVM/vhost for nested virtualization (e.g. KubeVirt, VM-building CI workers) and VFIO/UIO for DPDK-style userspace drivers on passthrough devices."],
  [%r{drivers/uio/},
    REMOVE, "Host Hypervisor Passthrough & vDPA",
    "UIO driver for specific industrial/embedded hardware."],

  # ---- recategorize leftovers of the old "Physical Hardware & Platform Drivers" catch-all ----
  [%r{ubuntu/dkms/zfs/},
    REMOVE, "ZFS",
    "OpenZFS (linux-main-modules-zfs); stemcells do not use ZFS (apply.sh also deletes the legacy kernel/zfs tree)."],
  [%r{drivers/net/(amt|bareudp|gtp|eql|pfcp|nlmon|vsockmon|rionet|ntb_netdev|thunderbolt/|mctp/|mhi_net)|net/ipv6/ila/|net/llc/llc2|net/802/psnap|net/(sctp|tipc)/\w+_diag|net/9p/9pnet_usbg},
    REMOVE, "Legacy / Obscure Network Protocols",
    "Niche tunnel, monitoring or transport (AMT, bare UDP, GTP, ILA, PF_LLC, SNAP, MCTP, RapidIO/NTB/Thunderbolt networking) or diag for a protocol removed here."],
  [%r{fs/fat/msdos|fs/romfs/|fs/pstore/},
    REMOVE, "Exotic / Untrusted Filesystems",
    "MS-DOS 8.3 FAT, ROMFS, or block/RAM pstore backends; vfat is built in and efi-pstore is retained."],
  [%r{ubuntu/ubuntu-host/|drivers/misc/ntsync|drivers/char/hangcheck-timer},
    REMOVE, "Miscellaneous",
    "Ubuntu LXD host marker, Wine NT sync primitives, or Oracle RAC hangcheck timer; not used on stemcells."],

  # ---- display: everything else in DRM is physical GPU/panel hardware ----
  [%r{drivers/gpu/drm/(amd|i915|xe|nouveau|radeon|gma500|mgag200|ast|udl|gud|vgem|vkms|tiny|panel|solomon|sitronix)/},
    REMOVE, "Physical Desktop & Server GPUs",
    "Physical GPU, server BMC display, USB display or panel driver; VM consoles use the retained virtual display drivers."]
].freeze

def module_name(path)
  File.basename(path).sub(/\.ko(\.\w+)?\z/, "")
end

def normalize(name)
  name.tr("-", "_")
end

def read_csv(path)
  header, *lines = CSV.read(path)
  abort "#{path}: unexpected header #{header.inspect}" unless header == FIELDS
  lines.to_h do |fields|
    # Tolerate an unquoted comma in the free-text reason column.
    fields = fields[0, 4] + [fields[4..].join(",")] if fields.size > FIELDS.size
    row = FIELDS.zip(fields).to_h
    [row["rel_path"], row]
  end
end

def parse_modules_dep(lines)
  lines.to_h do |line|
    mod, deps = line.split(":", 2)
    [mod, deps.to_s.split]
  end
end

# modules.softdep names modules, not paths: "softdep cifs pre: gcm ccm ..."
def parse_softdeps(lines, present)
  by_name = present.to_h { |p| [normalize(module_name(p)), p] }
  softdeps = Hash.new { |h, k| h[k] = [] }
  lines.each do |line|
    words = line.split
    next unless words.first == "softdep" && words.size >= 3

    mod = by_name[normalize(words[1])]
    next unless mod

    words[2..].each do |word|
      next if %w[pre: post:].include?(word) || word.start_with?("platform:")

      dep = by_name[normalize(word)]
      softdeps[mod] << dep if dep
    end
  end
  softdeps
end

def read_modules_dir(modules_dir)
  abort "#{modules_dir}/modules.dep not found; run depmod first" unless File.exist?(File.join(modules_dir, "modules.dep"))
  # Some modules differ only by case (xt_DSCP / xt_dscp); a case-insensitive
  # filesystem (the macOS default) silently keeps just one of each pair.
  if File.directory?(File.join(modules_dir, "kernel")) && File.exist?(File.join(modules_dir, "KERNEL"))
    abort "#{modules_dir} is on a case-insensitive filesystem, which merges modules whose names differ " \
      "only by case (e.g. xt_DSCP and xt_dscp). Unpack the kernel modules and run this script on a " \
      "case-sensitive filesystem, e.g. inside a Linux container, or pass the CI log instead."
  end
  softdep_path = File.join(modules_dir, "modules.softdep")
  {
    present: Dir.glob("**/*.ko*", base: modules_dir).sort,
    deps: parse_modules_dep(File.readlines(File.join(modules_dir, "modules.dep"), chomp: true)),
    softdep_lines: File.exist?(softdep_path) ? File.readlines(softdep_path, chomp: true) : []
  }
end

# Decodes the TRIAGE DATA blocks printed by remove_kernel_modules.sh. Tolerates
# log timestamps / ANSI colors around each line and several blocks (kernels).
def read_ci_log(log)
  lines = log.gsub(/\e\[[\d;]*m/, "").lines
  blocks = []
  base64 = nil
  lines.each do |line|
    if line.include?("--- BEGIN KERNEL MODULE TRIAGE DATA ---")
      base64 = +""
    elsif line.include?("--- END KERNEL MODULE TRIAGE DATA ---") && base64
      blocks << Zlib::GzipReader.new(StringIO.new(base64.unpack1("m"))).read
      base64 = nil
    elsif base64
      base64 << line.split.last.to_s
    end
  end
  abort "No KERNEL MODULE TRIAGE DATA block found in the CI log." if blocks.empty?

  data = {csvs: [], kernels: [], new: [], deps: {}, softdep_lines: []}
  blocks.join("\n").each_line(chomp: true) do |line|
    key, value = line.split(" ", 2)
    case key
    when "csv" then data[:csvs] |= [value]
    when "kernel" then data[:kernels] |= [value]
    when "new" then data[:new] |= [value]
    when "dep" then data[:deps].merge!(parse_modules_dep([value])) { |_, a, b| a | b }
    when "softdep" then data[:softdep_lines] << line
    end
  end
  abort "The CI log has triage data for several CSVs (#{data[:csvs].join(", ")}); pass one at a time." if data[:csvs].size > 1
  data
end

def triage(row)
  short = row["rel_path"].delete_prefix("kernel/")
  RULES.each do |pattern, remove, category, reason|
    return row.merge("remove" => remove, "category" => category, "reason" => reason) if pattern.match?(short)
  end
  # Re-derive dependency rows from scratch; the closure below keeps them if still needed.
  if row["category"] == DEP
    return row.merge("remove" => REMOVE, "category" => UNUSED_DEP,
      "reason" => "Only needed by modules that are removed.")
  end
  row
end

input = ARGV[0] || "-"
csv_dir = File.expand_path("../stemcell_builder/stages/system_kernel_modules", __dir__)
from_log = input == "-" || !File.directory?(input)
if from_log
  abort "usage: #{$PROGRAM_NAME} [<ci_log> | <modules_dir>] [csv]  (reading the CI log from stdin)" if input == "-" && $stdin.tty?
  abort "#{input}: no such CI log or modules directory\nusage: #{$PROGRAM_NAME} [<ci_log> | <modules_dir>] [csv]" unless input == "-" || File.file?(input)
  modules = read_ci_log((input == "-") ? $stdin.read : File.read(input))
  csv_path = ARGV[1] || File.join(csv_dir, modules[:csvs].first || "linux-generic.csv")
  old = read_csv(csv_path)
  # The log only lists new modules; everything already in the CSV is assumed present.
  present = (old.keys | modules[:new]).sort
  puts "Read triage data for kernel #{modules[:kernels].join(", ")}: #{modules[:new].size} new modules."
else
  modules = read_modules_dir(input)
  csv_path = ARGV[1] || File.join(csv_dir, "linux-generic.csv")
  old = read_csv(csv_path)
  present = modules[:present]
end
deps = modules[:deps]
softdeps = parse_softdeps(modules[:softdep_lines], present)

untriaged = []
rows = (present | old.keys).to_h do |path|
  existing = old[path]&.dup || {"module_name" => module_name(path), "rel_path" => path}
  row = triage(existing)
  untriaged << path unless row["remove"]
  [path, row]
end
unless untriaged.empty?
  abort "No rule matches these new modules; add rules or CSV rows for them:\n" +
    untriaged.map { |p| "  #{p}\n" }.join
end

# Keep every dependency of a kept module, recording which kept modules need it.
required_by = Hash.new { |h, k| h[k] = Set.new }
queue = rows.keys.select { |p| rows[p]["remove"] == KEEP }
until queue.empty?
  path = queue.shift
  (deps.fetch(path, []) + softdeps.fetch(path, [])).each do |dep|
    next unless rows.key?(dep)

    required_by[dep] << module_name(path) if rows[dep]["remove"] != KEEP || required_by.key?(dep)
    next if rows[dep]["remove"] == KEEP

    rows[dep]["remove"] = KEEP
    queue << dep
  end
end
required_by.each do |dep, users|
  rows[dep]["category"] = DEP
  rows[dep]["reason"] = "Required by retained module(s): #{users.sort.join(", ")}."
end

rows.each do |path, row|
  next unless row["remove"] == KEEP

  deps.fetch(path, []).each do |dep|
    raise "#{path} is kept but its dependency #{dep} is not" unless rows.dig(dep, "remove") == KEEP
  end
end

# The CI log only has modules.dep lines for modules that were remove=No or new.
# modules.dep is transitive, so modules kept as dependencies are covered.
unknown = rows.keys.select do |p|
  rows[p]["remove"] == KEEP && old.dig(p, "remove") != KEEP && !deps.key?(p) && !required_by.key?(p)
end
if from_log && !unknown.empty?
  puts "WARNING: dependencies unknown for these newly kept modules; the next stemcell build checks them:",
    unknown.map { |p| "  #{p}" }
end

sorted = rows.values.sort_by do |r|
  [(r["remove"] == KEEP) ? 1 : 0, r["category"], r["module_name"].downcase, r["rel_path"]]
end
File.write(csv_path, CSV.generate(quote_empty: false) do |csv|
  csv << FIELDS
  sorted.each { |r| csv << r.values_at(*FIELDS) }
end)

changed = rows.values.select { |r| old[r["rel_path"]] && old[r["rel_path"]]["remove"] != r["remove"] }
added = rows.keys - old.keys
counts = rows.values.map { |r| r["remove"] }.tally
puts "Wrote #{csv_path}: #{counts[REMOVE].to_i} remove=Yes, #{counts[KEEP].to_i} remove=No."
def describe(row)
  "  #{row["rel_path"]}\n    remove=#{row["remove"]} (#{row["category"]}): #{row["reason"]}"
end

unless added.empty?
  puts "Added #{added.size} rows:"
  added.each { |p| puts describe(rows[p]) }
end
unless changed.empty?
  puts "Changed #{changed.size} decisions:"
  changed.sort_by { |r| r["rel_path"] }.each { |r| puts describe(r) }
end
# Only report dependency rows whose reason changed and that aren't listed above.
new_deps = required_by.keys.reject do |dep|
  old.dig(dep, "reason") == rows[dep]["reason"] || added.include?(dep) || changed.include?(rows[dep])
end
unless new_deps.empty?
  puts "Now needed by different retained modules (dependency <- modules that need it):"
  new_deps.sort.each { |dep| puts "  #{dep} <- #{required_by[dep].sort.join(", ")}" }
end
