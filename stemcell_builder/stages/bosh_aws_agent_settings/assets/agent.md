# Introduction
The problem that we have is that the diskID provided by the IAAS does not correspond with the diskID on the vm as you can see in the related information part.
Therefore, we are trying to mitigate this issue by using diskIdTransformation as you can see in the example below

Do note that if this fails it will always fallback to other means of mounting the disk

## Disk ID transform rules
the following 2 json entries
```
"DiskIDTransformPattern": "^vol-(.+)$",
"DiskIDTransformReplacement": "nvme-Amazon_Elastic_Block_Store_vol${1}"
```

## what it does
the `DiskIDTransformPattern` will match `vol-04b2a40747d7e9625` in to 1 group `04b2a40747d7e9625`
the `DiskIDTransformReplacement` will match and replace `04b2a40747d7e9625` with `nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625`

the agent will then glob and mount `/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625`

## related information
contents of persistent_disk_hints.json
```
{
  "vol-04b2a40747d7e9625": {
    "ID": "vol-04b2a40747d7e9625",
    "DeviceID": "",
    "VolumeID": "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625",
    "Lun": "",
    "HostDeviceID": "",
    "Path": "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625",
    "ISCSISettings": {
      "InitiatorName": "",
      "Username": "",
      "Target": "",
      "Password": ""
    },
    "FileSystemType": "",
    "MountOptions": null,
    "Partitioner": ""
  }
}
```

files listed in `/dev/disk/by-id`
```
nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625
nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625_1
nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625_1-part1
nvme-Amazon_Elastic_Block_Store_vol04b2a40747d7e9625-part1
nvme-Amazon_Elastic_Block_Store_vol0c2ee6da5d33b8f8b
nvme-Amazon_Elastic_Block_Store_vol0c2ee6da5d33b8f8b_1
nvme-Amazon_Elastic_Block_Store_vol0c2ee6da5d33b8f8b_1-part1
nvme-Amazon_Elastic_Block_Store_vol0c2ee6da5d33b8f8b_1-part2
nvme-Amazon_Elastic_Block_Store_vol0c2ee6da5d33b8f8b-part1
nvme-Amazon_Elastic_Block_Store_vol0c2ee6da5d33b8f8b-part2
nvme-Amazon_Elastic_Block_Store_vol0c67d3300b92fe851
nvme-Amazon_Elastic_Block_Store_vol0c67d3300b92fe851_1
nvme-Amazon_Elastic_Block_Store_vol0c67d3300b92fe851_1-part1
nvme-Amazon_Elastic_Block_Store_vol0c67d3300b92fe851-part1
nvme-nvme.1d0f-766f6c3034623261343037343764376539363235-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001
nvme-nvme.1d0f-766f6c3034623261343037343764376539363235-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001-part1
nvme-nvme.1d0f-766f6c3063326565366461356433336238663862-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001
nvme-nvme.1d0f-766f6c3063326565366461356433336238663862-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001-part1
nvme-nvme.1d0f-766f6c3063326565366461356433336238663862-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001-part2
nvme-nvme.1d0f-766f6c3063363764333330306239326665383531-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001
nvme-nvme.1d0f-766f6c3063363764333330306239326665383531-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001-part1
```