#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p /etc/systemd/system/chrony.service.d

cat > $chroot/etc/systemd/system/chrony.service.d/chrony-systemd-override.conf <<EOF
# created by $0
[Service]
# Set the CPU scheduling policy to FIFO (First-In, First-Out), a real-time policy.
CPUSchedulingPolicy=fifo

# Set the real-time priority to the highest possible value (99).
# This ensures chronyd runs before any other non-kernel, non-real-time tasks.
CPUSchedulingPriority=50

# Make the process less likely to be killed by the OOM killer
OOMScoreAdjust=-500
EOF

cat > $chroot/etc/chrony/conf.d/azure_ptp.conf <<EOF
# created by $0
# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/time-sync#chrony
refclock PHC /dev/ptp_hyperv poll -1 dpoll -2 offset 0 stratum 2
EOF
