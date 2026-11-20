#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"

chroot="$base_dir/../../work/work/chroot"

# GDCH stemcells never apt against the public Ubuntu archive: airgapped VMs can't
# reach it, and connected GDCH VMs get their packages from BOSH releases, not apt.
# The shared restore_apt_sources stage (which runs just before this one) writes
# archive.ubuntu.com/security.ubuntu.com into the classic sources.list. Left in
# place on an airgapped VM, apt's boot-time check stalls on each unreachable host.
# This stage runs after it and strips every apt source so no stemcell apt source
# points at an unreachable public mirror.

# Classic list written by restore_apt_sources.
: > "$chroot/etc/apt/sources.list"

# Noble ships apt sources in deb822 format. cloud-init regenerates
# /etc/apt/sources.list.d/ubuntu.sources on first boot from this OS-provided
# template, so emptying the rendered file would not survive. Neutralize the
# template itself so the first-boot render produces no public sources.
deb822_tmpl="$chroot/etc/cloud/templates/sources.list.ubuntu.deb822.tmpl"
if [ -f "$deb822_tmpl" ]; then
  : > "$deb822_tmpl"
fi

# Any deb822 sources already present in the image.
find "$chroot/etc/apt/sources.list.d" -maxdepth 1 -type f \
  \( -name '*.list' -o -name '*.sources' \) -delete 2>/dev/null || true