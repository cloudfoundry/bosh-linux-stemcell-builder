#!/usr/bin/env bash
base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

agent_settings_file=$chroot/var/vcap/bosh/agent.json

cat > $agent_settings_file <<JSON
{
  "Platform": {
    "Linux": {
      "DevicePathResolutionType": "",
      "SkipDiskSetup": false,
      "CreatePartitionIfNoEphemeralDisk": true,
      "PartitionerType": "parted"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254",
          "UserDataPath": "/opc/v1/instance/metadata/bosh_agent_userdata",
          "InstanceIDPath":  "/opc/v1/instance/id"
        }
      ],
      "UseServerName": false,
      "UseRegistry": true
    }
  }
}
JSON

