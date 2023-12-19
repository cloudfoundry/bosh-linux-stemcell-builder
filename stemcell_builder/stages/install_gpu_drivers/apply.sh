#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp "$(dirname "$0")/assets/cuda-keyring_1.1-1_all.deb" "${chroot}/tmp/cuda-keyring_1.1-1_all.deb"

run_in_chroot $chroot "
  dpkg -i /tmp/cuda-keyring_1.1-1_all.deb
"
pkg_mgr install nvidia-container-toolkit cuda libnvidia-container-tools libcudnn8

run_in_chroot $chroot "
  chmod 755 /usr/local/bin/nsys
  chmod 755 /usr/bin/nvidia-modprobe
"