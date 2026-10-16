#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

dir=$(dirname "$0")
base_dir=$(readlink -nf "$dir/../..")
assets_dir="$dir"/assets
chroot="$base_dir/../../work/work/chroot"
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

install -D -m 0755 \
  "$assets_dir/root/firstboot.sh" \
  "$chroot/root/firstboot.sh"

install -D -m 0644 \
  "$assets_dir/etc/systemd/system/firstboot.service" \
  "$chroot/etc/systemd/system/firstboot.service"

run_in_chroot "$chroot" "systemctl enable firstboot.service"
