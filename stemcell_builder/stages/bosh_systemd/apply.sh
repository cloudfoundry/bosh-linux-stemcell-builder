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
