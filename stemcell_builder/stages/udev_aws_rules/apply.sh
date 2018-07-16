#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cp $dir/assets/70-ec2-nvme-devices.rules $chroot/etc/udev/rules.d/70-ec2-nvme-devices.rules
cp $dir/assets/nvme-id $chroot/sbin/nvme-id

chmod 0755 $chroot/sbin/nvme-id
