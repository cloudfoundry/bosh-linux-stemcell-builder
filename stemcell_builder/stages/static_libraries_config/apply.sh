#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash
source $base_dir/etc/settings.bash

# amd64 keeps the original list file; other architectures use a suffixed list
# because the library paths contain the multiarch triplet.
list_file="${assets_dir}/static_libraries_list.txt"
if [ "$(stemcell_target_arch)" != "amd64" ]; then
  list_file="${assets_dir}/static_libraries_list_$(stemcell_target_arch).txt"
fi
if [ ! -f "${list_file}" ]; then
  echo "No static libraries list for architecture $(stemcell_target_arch): ${list_file}" >&2
  exit 1
fi
cp -p "${list_file}" $chroot/var/vcap/bosh/etc/static_libraries_list

kernel_suffix="-generic"
major_kernel_version="6.8"

if [[ "${stemcell_operating_system_variant}" == 'fips' ]]; then
    # TODO use iaas specific kernel
    # kernel_suffix="-${stemcell_infrastructure}-fips"
    kernel_suffix="-fips"
    major_kernel_version="6.8"
fi

update_kernel_static_libraries ${kernel_suffix} ${major_kernel_version}
