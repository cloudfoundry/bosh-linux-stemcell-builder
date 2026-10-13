#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

dir=$(dirname "$0")
base_dir=$(readlink -nf "$dir/../..")
assets_dir="$dir"/assets
chroot="$base_dir/../../work/work/chroot"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

cp "$assets_dir/etc/rc.local" "$chroot/etc/rc.local"
cp "$assets_dir/root/firstboot.sh" "$chroot/root/firstboot.sh"
chmod u+x "${chroot}/etc/rc.local"
chmod 0755 "$chroot/root/firstboot.sh"
