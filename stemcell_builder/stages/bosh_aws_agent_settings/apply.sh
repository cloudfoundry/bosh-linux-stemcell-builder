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
      ${partitioner_type:-}
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254",
          "UserDataPath": "/latest/user-data",
          "InstanceIDPath": "/latest/meta-data/instance-id",
          "SSHKeysPath": "/latest/meta-data/public-keys/0/openssh-key"
        }
      ],
      "UseRegistry": true
    }
  }
}
JSON
