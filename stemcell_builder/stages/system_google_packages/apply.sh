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
  run_in_chroot "${chroot}" "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"

  run_in_chroot "${chroot}" "tee /etc/apt/sources.list.d/google-cloud.list << EOM
deb http://packages.cloud.google.com/apt google-compute-engine-stretch-stable main
deb http://packages.cloud.google.com/apt google-cloud-packages-archive-keyring-stretch main
EOM"

  pkg_mgr install "google-cloud-packages-archive-keyring"
  pkg_mgr install "--target-release google-compute-engine-stretch-stable python-google-compute-engine python3-google-compute-engine"
  pkg_mgr install "google-compute-engine-oslogin google-compute-engine"

  run_in_chroot "${chroot}" "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python3/dist-packages/google_compute_engine/metadata_watcher.py"

  # Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
  run_in_chroot "${chroot}" "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/dist-packages/google_compute_engine/metadata_watcher.py"

  set_hostname_path=/etc/dhcp/dhclient-exit-hooks.d/google_set_hostname
elif [ "${os_type}" == "rhel"  ] || [ "${os_type}" == "centos" ]; then # http://tldp.org/LDP/abs/html/ops.html#ANDOR TURN AND FACE THE STRANGE (ch-ch-changes)
  # Copy google daemon packages into chroot
  cp -R "$assets_dir/google-centos/"*.rpm "$chroot/tmp/google/"

  run_in_chroot "${chroot}" "yum install -y python-setuptools python-boto"

  run_in_chroot "${chroot}" "yum --nogpgcheck install -y /tmp/google/*.rpm"

  # Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
  run_in_chroot "${chroot}" "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/site-packages/google_compute_engine/metadata_watcher.py"

  set_hostname_path=/etc/dhcp/dhclient.d/google_hostname.sh
else
  echo "Unknown OS '${os_type}', exiting"
  exit 2
fi

# See https://github.com/cloudfoundry/bosh/issues/1399 for context
run_in_chroot "${chroot}" "rm --interactive=never ${set_hostname_path}"

