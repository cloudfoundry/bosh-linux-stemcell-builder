#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"

chroot="$base_dir/../../work/work/chroot"
input_file="$chroot/etc/chrony/chrony.conf"

# Remove any remaining default Ubuntu pool directives and configure GDC internal NTP servers
sed -i "/^pool /d" "$input_file"
sed -i "/^server ntp[123]\.org\.internal$/d" "$input_file"

cat >>"$input_file" <<EOF
server ntp1.org.internal
server ntp2.org.internal
server ntp3.org.internal
EOF
