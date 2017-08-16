#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ "$(get_os_type)" == "opensuse" ]; then
  partitioner_type="\"PartitionerType\": \"parted\","
fi

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      ${partitioner_type:-}
      "DevicePathResolutionType": "virtio",
      "VirtioDevicePrefix": "google"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "InstanceMetadata",
          "URI": "http://169.254.169.254",
          "SettingsPath": "/computeMetadata/v1/instance/attributes/bosh_settings",
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
