#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_agent.bash

# Set SettingsPath but never use it because file_meta_service is available only when the settings file exists.
cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      $(get_partitioner_type_mapping)
      "CreatePartitionIfNoEphemeralDisk": true,
      "ScrubEphemeralDisk": true,
      "DevicePathResolutionType": "iscsi"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "https://api.service.softlayer.com",
          "UserDataPath": "/rest/v3.1/SoftLayer_Resource_Metadata/getUserMetadata.json"
        }
      ],
      "UseServerName": true,
      "UseRegistry": true
    }
  }
}

JSON