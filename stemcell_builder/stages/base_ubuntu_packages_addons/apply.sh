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

# additional ubuntu packages to be installed for GDC beyond those in base_ubuntu_packages
debs_addson="cloud-init selinux-utils policycoreutils tree jq cracklib-runtime"

pkg_mgr install "$debs_addson"

restrict_binary_setuid
