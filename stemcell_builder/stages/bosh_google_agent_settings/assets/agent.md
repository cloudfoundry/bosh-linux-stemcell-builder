# Introduction
The problem that we have is that the diskID provided by the IAAS does not correspond with the diskID on the vm as you can see in the related information part.
Therefore, we are trying to mitigate this issue by using diskIdTransformation as you can see in the example below

Do note that if this fails it will always fallback to other means of mounting the disk

## Disk ID transform rules
the following 2 json entries
```
"DiskIDTransformPattern": "^(disk-.+)$",
"DiskIDTransformReplacement": "google-${1}"
```

## what it does
the `DiskIDTransformPattern` will match `disk-69e53b13-76b3-4400-4437-633782a5cbb5` in to 1 group `disk-69e53b13-76b3-4400-4437-633782a5cbb5`
the `DiskIDTransformReplacement` will match and replace ``disk-69e53b13-76b3-4400-4437-633782a5cbb5` with `google-disk-69e53b13-76b3-4400-4437-633782a5cbb5`

the agent will then glob and mount `/dev/disk/by-id/google-disk-69e53b13-76b3-4400-4437-633782a5cbb5`

## related information
contents of `persistent_disk_hints.json`
```
{
  "disk-69e53b13-76b3-4400-4437-633782a5cbb5": {
    "ID": "disk-69e53b13-76b3-4400-4437-633782a5cbb5",
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
google-disk-69e53b13-76b3-4400-4437-633782a5cbb5
google-disk-69e53b13-76b3-4400-4437-633782a5cbb5-part1
google-persistent-disk-0
google-persistent-disk-0-part1
google-persistent-disk-0-part2
google-persistent-disk-0-part3
google-persistent-disk-0-part4
scsi-0Google_PersistentDisk_disk-69e53b13-76b3-4400-4437-633782a5cbb5
scsi-0Google_PersistentDisk_disk-69e53b13-76b3-4400-4437-633782a5cbb5-part1
scsi-0Google_PersistentDisk_persistent-disk-0
scsi-0Google_PersistentDisk_persistent-disk-0-part1
scsi-0Google_PersistentDisk_persistent-disk-0-part2
scsi-0Google_PersistentDisk_persistent-disk-0-part3
scsi-0Google_PersistentDisk_persistent-disk-0-part4
```nvme.1d0f-766f6c3063363764333330306239326665383531-416d617a6f6e20456c617374696320426c6f636b2053746f7265-00000001-part1
```