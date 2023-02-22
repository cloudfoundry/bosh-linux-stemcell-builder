#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cp -p "${assets_dir}/${DISTRIB_CODENAME}_static_libraries_list.txt" $chroot/var/vcap/bosh/etc/static_libraries_list

if [[ "${DISTRIB_CODENAME}" == 'bionic' ]]; then
    major_kernel_version="5.4"
elif [[ "${DISTRIB_CODENAME}" == 'jammy' ]]; then
    major_kernel_version="5.19"
else
    major_kernel_version="4.15"
fi
kernel_version=$(find $chroot/usr/src/ -name "linux-headers-$major_kernel_version.*-generic" | grep -o '[0-9].*-[0-9]*-generic')
sed -i "s/__KERNEL_VERSION__/$kernel_version/g" $chroot/var/vcap/bosh/etc/static_libraries_list