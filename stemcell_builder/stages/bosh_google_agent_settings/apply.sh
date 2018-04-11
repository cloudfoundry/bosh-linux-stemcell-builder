#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_agent.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      $(get_google_partitioner_type_mapping)
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
