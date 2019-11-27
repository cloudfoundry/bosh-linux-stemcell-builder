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

pkg_mgr install "gce-compute-image-packages google-compute-engine-oslogin python-google-compute-engine python3-google-compute-engine"


# Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
run_in_chroot "${chroot}" "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python3/dist-packages/google_compute_engine/metadata_watcher.py"
run_in_chroot "${chroot}" "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/dist-packages/google_compute_engine/metadata_watcher.py"

set_hostname_path=/etc/dhcp/dhclient-exit-hooks.d/google_set_hostname

# See https://github.com/cloudfoundry/bosh/issues/1399 for context
run_in_chroot "${chroot}" "rm --interactive=never ${set_hostname_path}"

