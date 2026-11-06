#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p "${chroot}/etc/systemd/resolved.conf.d/"
cp "$(dirname "$0")/assets/add-container-listener-address.conf" "${chroot}/etc/systemd/resolved.conf.d/"

cp "$(dirname "$0")/assets/create-systemd-resolved-listener-address.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable create-systemd-resolved-listener-address.service"
