# Introduction
The problem that we have is that the diskID provided by the IAAS does not correspond with the diskID on the vm as you can see in the related information part.
Therefore, we are trying to mitigate this issue by using diskIdTransformation as you can see in the example below

Do note that if this fails it will always fallback to other means of mounting the disk

## Disk ID transform rules
the following 2 json entries
```
"DiskIDTransformPattern": "^([0-9a-f]{8})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{12})$",
"DiskIDTransformReplacement": "scsi-${1}${2}${3}${4}${5}"
```

## what it does
the `DiskIDTransformPattern` will match `05c185c6-e8a3-4216-ab30-1f5cf7d17f0d` in to 5 groups `05c185c6`, `e8a3`, `4216`, `ab30`, `1f5cf7d17f0d`
the `DiskIDTransformReplacement` will match and replace `scsi-` with the 5 groups `scsi-305c185c6e8a34216ab301f5cf7d17f0d`

the agent will then glob and mount `/dev/disk/by-id/scsi-305c185c6e8a34216ab301f5cf7d17f0d`

## related information
contents of `persistent_disk_hints.json`
```
{
  "05c185c6-e8a3-4216-ab30-1f5cf7d17f0d": {
    "ID": "05c185c6-e8a3-4216-ab30-1f5cf7d17f0d",
    "DeviceID": "",
    "VolumeID": "/dev/sdb",
    "Lun": "",
    "HostDeviceID": "",
    "Path": "/dev/sdb",
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
scsi-305c185c6e8a34216ab301f5cf7d17f0d
scsi-305c185c6e8a34216ab301f5cf7d17f0d-part1
scsi-36000c295e04c2c9a4b447d59632b887b
scsi-36000c295e04c2c9a4b447d59632b887b-part1
scsi-36000c295e04c2c9a4b447d59632b887b-part2
scsi-36000c295e04c2c9a4b447d59632b887b-part3
wwn-0x05c185c6e8a34216ab301f5cf7d17f0d
wwn-0x05c185c6e8a34216ab301f5cf7d17f0d-part1
wwn-0x6000c295e04c2c9a4b447d59632b887b
wwn-0x6000c295e04c2c9a4b447d59632b887b-part1
wwn-0x6000c295e04c2c9a4b447d59632b887b-part2
wwn-0x6000c295e04c2c9a4b447d59632b887b-part3
```