#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

export KERNEL=`ls ${chroot}/boot/initramfs* | sed -e "s/^.*\/initramfs-//; s/.img//"`

drivers='ata_generic pata_acpi floppy loop brd xen-blkfront virtio_blk virtio_net virtio_pci virtio_scsi mptspi mptbase mptscsih 3w-9xxx 3w-sas arcmsr bfa fnic hpsa hptiop hv_vmbus hv_storvsc initio isci libsas lpfc megaraid_sas mpt2sas mpt3sas mtip32xx mvsas mvumi nvme pm80xx pmcraid aic79xx qla2xxx qla4xxx raid_class stex sx8 vmw_pvscsi'

run_in_chroot $chroot "dracut --force --add-drivers '${drivers}' --kver ${KERNEL}"
