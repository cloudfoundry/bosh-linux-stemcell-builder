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

# See https://www.pivotaltracker.com/n/projects/956238/stories/175098267 for context
echo "" > "$chroot/etc/growroot-disabled"

pkg_mgr install "gce-compute-image-packages"

# See https://github.com/cloudfoundry/bosh/issues/1399 for context
set_hostname_path=/etc/dhcp/dhclient-exit-hooks.d/google_set_hostname
run_in_chroot "${chroot}" "rm --interactive=never ${set_hostname_path}"
