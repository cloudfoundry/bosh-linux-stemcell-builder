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
      "DevicePathResolutionType": "scsi"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "CDROM",
          "FileName": "env"
        }
      ]
    }
  }
}
JSON
