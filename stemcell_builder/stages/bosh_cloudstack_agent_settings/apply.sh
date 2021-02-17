#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_agent.bash

agent_settings_file=$chroot/var/vcap/bosh/agent.json

cat > $agent_settings_file <<JSON
{
  "Platform": {
    "Linux": {
      $(get_partitioner_type_mapping)
      "CreatePartitionIfNoEphemeralDisk": true,
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254:39724",
          "UserDataPath": "/latest/user-data",
          "InstanceIDPath": "/latest/meta-data/instance-id",
          "SSHKeysPath": "/latest/meta-data/public-keys"
        }
      ],
      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON
