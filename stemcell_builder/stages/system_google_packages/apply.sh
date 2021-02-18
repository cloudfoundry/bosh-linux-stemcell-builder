#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir="$(readlink -nf "$(dirname "$0")/../..")"
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"

# Configure the Google guest environment
# https://github.com/GoogleCloudPlatform/compute-image-packages#configuration
cp "$assets_dir/instance_configs.cfg.template" "$chroot/etc/default/"

mkdir -p "$chroot/tmp/google"

declare set_hostname_path

os_type="$(get_os_type)"
if [[ "${os_type}" == "ubuntu" ]] ; then
  pkg_mgr install "gce-compute-image-packages"

  set_hostname_path=/etc/dhcp/dhclient-exit-hooks.d/google_set_hostname
elif [ "${os_type}" == "rhel"  ] || [ "${os_type}" == "centos" ]; then # http://tldp.org/LDP/abs/html/ops.html#ANDOR TURN AND FACE THE STRANGE (ch-ch-changes)
  # Copy google daemon packages into chroot
  cp -R "$assets_dir/google-centos/"*.rpm "$chroot/tmp/google/"

  run_in_chroot "${chroot}" "yum install -y python-setuptools python-boto"

  run_in_chroot "${chroot}" "yum --nogpgcheck install -y /tmp/google/*.rpm"

  set_hostname_path=/etc/dhcp/dhclient.d/google_hostname.sh
else
  echo "Unknown OS '${os_type}', exiting"
  exit 2
fi

# See https://github.com/cloudfoundry/bosh/issues/1399 for context
run_in_chroot "${chroot}" "rm --interactive=never ${set_hostname_path}"

