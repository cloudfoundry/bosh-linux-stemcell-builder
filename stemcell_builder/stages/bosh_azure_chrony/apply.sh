#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cat > $chroot/etc/chrony/conf.d/azure_ptp.conf <<EOF
# created by $0
# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/time-sync#chrony
refclock PHC /dev/ptp0 poll 3 dpoll -2 offset 0
EOF
