#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_config.bash
source "$base_dir/lib/prelude_config.bash"

persist_value stemcell_image_name
