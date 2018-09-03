#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Set SettingsPath but never use it because file_meta_service is avaliable only when the settings file exists.
cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "DevicePathResolutionType": "scsi",
      "PartitionerType": "parted"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "ConfigDrive",
          "DiskPaths": [
            "/dev/disk/by-label/azure_cfg_dsk",
            "/dev/disk/by-label/AZURE_CFG_DSK"
          ],
          "MetaDataPath": "configs/MetaData",
          "UserDataPath": "configs/UserData"
        },
        {
          "Type": "File",
          "MetaDataPath": "",
          "UserDataPath": "/var/lib/waagent/CustomData",
          "SettingsPath": "/var/lib/waagent/CustomData"
        }
      ],
      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON
