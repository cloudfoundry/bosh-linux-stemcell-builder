#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"

work="$base_dir/../../work/work"
pushd "$work"

stemcell_image_name=${stemcell_image_name:-"${stemcell_infrastructure}-kvm-ubuntu.raw"}
rm -f disk.raw
ln "$stemcell_image_name" disk.raw

# since GDC VMM only takes raw and qcow2 images, instead of making an additional compression as in
# prepare_rawdisk_image_stemcell, GDC directly packages the raw image as `image` in the stemcell tarball
mv disk.raw stemcell/image
popd
