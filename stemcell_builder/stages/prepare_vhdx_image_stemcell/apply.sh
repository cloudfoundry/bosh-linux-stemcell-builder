#!/usr/bin/env bash
#
set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
source "$base_dir/lib/prelude_apply.bash"

rm -f "$work/root.vhd"

# Convert raw to dynamic VHD
qemu-img convert -O vpc -o subformat=dynamic "$work/${stemcell_image_name}" "$work/root.vhd"

#Verification:
vhd-util check -n "$work/root.vhd"
vhd-util read -p -n "$work/root.vhd"
ls -lh "$work/root.vhd"

pushd "$work"
"$(command -v lbzip2 2>/dev/null || command -v bzip2)" -c root.vhd > stemcell/image
popd
