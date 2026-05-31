#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Disable RemoveIPC in systemd to prevent it from cleaning up shared files owned by vcap
# Postgres for example gets the error message: could not open shared memory segment
# because those files have been cleaned up
run_in_chroot $chroot "
echo 'RemoveIPC=no' >> /etc/systemd/logind.conf
"

# systemd 259 (Ubuntu 26.04) mounts /tmp as a tmpfs by default via the static
# tmp.mount unit, making /tmp RAM-backed and size-limited rather than the
# disk-backed directory BOSH stemcells have historically shipped. That can
# surprise jobs that write large temp files to /tmp (it competes with VM RAM).
# Mask tmp.mount so /tmp stays a regular directory on the root filesystem,
# preserving the pre-systemd-259 behaviour. (/tmp keeps the conventional 1777
# permissions applied by systemd-tmpfiles; jobs should still use
# /var/vcap/data/tmp for scratch space.)
run_in_chroot $chroot "systemctl mask tmp.mount"
