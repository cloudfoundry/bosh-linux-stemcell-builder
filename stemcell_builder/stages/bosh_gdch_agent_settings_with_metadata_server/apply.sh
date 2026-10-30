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

bosh_agent_unit_file="$chroot/usr/lib/systemd/system/bosh-agent.service"

sed -i '/^\[Unit\]/a StartLimitInterval=660\nStartLimitBurst=10' "$bosh_agent_unit_file"
sed -i '/^\[Service\]/a Restart=always\nRestartSec=60' "$bosh_agent_unit_file"

# vend BOSH agent settings in a metadata server
cat >"$chroot/var/vcap/bosh/agent.json" <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "PartitionerType": "parted",
      "DevicePathResolutionType": "virtio",
      "VirtioDevicePrefix": "gdch",
      "ServiceManager": "systemd"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "InstanceMetadata",
          "URI": "http://169.254.169.254",
          "SettingsPath": "/computeMetadata/v1/instance/attributes/bosh-settings",
          "Headers": {
            "Metadata-Flavor": "Google"
          }
        }
      ],
      "UseServerName": true,
      "UseRegistry": false
    }
  }
}
JSON
