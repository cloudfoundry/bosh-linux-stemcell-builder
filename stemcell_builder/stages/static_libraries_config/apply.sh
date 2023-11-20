#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash
source $base_dir/etc/settings.bash

cp -p "${assets_dir}/${DISTRIB_CODENAME}_static_libraries_list.txt" $chroot/var/vcap/bosh/etc/static_libraries_list

kernel_suffix="-generic"
if [[ "${DISTRIB_CODENAME}" == 'bionic' ]]; then
    major_kernel_version="5.4"
elif [[ "${DISTRIB_CODENAME}" == 'jammy' ]]; then
    major_kernel_version="6.2"
else
    major_kernel_version="4.15"
fi

if [[ "${stemcell_operating_system_variant}" == 'fips' ]]; then
    kernel_suffix="-${stemcell_infrastructure}-fips"
    major_kernel_version="4.15"
fi

update_kernel_static_libraries ${kernel_suffix} ${major_kernel_version}
