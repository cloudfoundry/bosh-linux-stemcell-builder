#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_agent.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      $(get_partitioner_type_mapping)
      "DevicePathResolutionType": "virtio",
      "CreatePartitionIfNoEphemeralDisk": true,
      "DNSResolverType": "systemd"
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
          "SSHKeysPath": "/latest/meta-data/public-keys/0/openssh-key",
          "TokenPath": "/latest/api/token"
        }
      ],
      "UseRegistry": true
    }
  }
}
JSON
