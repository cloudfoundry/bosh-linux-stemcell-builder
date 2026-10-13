#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

chroot="$base_dir/../../work/work/chroot"
# vend BOSH agent settings in a local file
cat >"$chroot/var/vcap/bosh/agent.json" <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "PartitionerType": "parted",
      "DevicePathResolutionType": "virtio",
      "VirtioDevicePrefix": "gdch"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "_comment for Type": "signify the source is in local file system",
          "Type": "File",
          "_comment for SettingsPath": "/home/bosh-ssh-user is the home directory of ssh user used by ssh agent in GDC BOSH CPI",
          "SettingsPath": "/home/bosh-ssh-user/bosh-settings.json"
        }
      ],
      "UseServerName": true,
      "UseRegistry": false
    }
  }
}
JSON
