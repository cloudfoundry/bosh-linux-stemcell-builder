#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash
source $base_dir/lib/helpers.sh

assert_available debootstrap

if [ ! -z "${UBUNTU_ISO:-}" ]
then
  persist UBUNTU_ISO
fi

if [ ! -z "${UBUNTU_DEBOOTSTRAP_MIRROR:-}" ]
then
  persist UBUNTU_DEBOOTSTRAP_MIRROR
fi

# Architecture of the stemcell being built. Defaults to amd64 so existing
# builds are unaffected; set stemcell_arch=arm64 (via settings.bash) to build
# an ARM64 stemcell.
base_debootstrap_arch="${stemcell_arch:-amd64}"

if [ -z "${base_debootstrap_suite:-}" ]
then
  base_debootstrap_suite=$stemcell_operating_system_version
fi

persist_value base_debootstrap_arch
persist_value base_debootstrap_suite
