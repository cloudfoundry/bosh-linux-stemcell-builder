#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

# add 'bosh-ssh-user' used by GDC CPI to user group 'bosh_sshers' for ssh access
chroot="$base_dir/../../work/work/chroot"
bosh_ssh_user_group="bosh_sshers"
gdch_ssh_user="bosh-ssh-user"

run_in_chroot "$chroot" "
useradd -m $gdch_ssh_user -c 'GDC BOSH ssh user'
usermod -G $bosh_ssh_user_group $gdch_ssh_user
usermod -s /bin/bash $gdch_ssh_user
"
