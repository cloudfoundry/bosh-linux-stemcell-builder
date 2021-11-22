#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

pkg_mgr install build-essential
pkg_mgr install gcc-9 g++-9
pkg_mgr purge gcc-10 g++-10
