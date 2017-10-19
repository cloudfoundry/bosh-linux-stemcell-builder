#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://100.100.100.200",
          "InstanceIDPath": "/latest/meta-data/instance-id",
          "UserDataPath": "/latest/user-data"
        }
      ],
      "UseServerName": false,
      "UseRegistry": true
    }
  }
}
JSON
