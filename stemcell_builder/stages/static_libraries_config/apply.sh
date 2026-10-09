#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash
source $base_dir/etc/settings.bash

cp -p "${assets_dir}/static_libraries_list.txt" $chroot/var/vcap/bosh/etc/static_libraries_list

# The list is written with the x86_64 multiarch triplet. On arm64 the same
# libraries live under aarch64-linux-gnu. RFC: cloudfoundry/community#1530
if [ "$(stemcell_target_arch)" == "arm64" ]; then
  sed -i 's/x86_64-linux-gnu/aarch64-linux-gnu/g' $chroot/var/vcap/bosh/etc/static_libraries_list
fi

kernel_suffix="-generic"
major_kernel_version="6.8"

if [[ "${stemcell_operating_system_variant}" == 'fips' ]]; then
    # TODO use iaas specific kernel
    # kernel_suffix="-${stemcell_infrastructure}-fips"
    kernel_suffix="-fips"
    major_kernel_version="6.8"
fi

update_kernel_static_libraries ${kernel_suffix} ${major_kernel_version}
