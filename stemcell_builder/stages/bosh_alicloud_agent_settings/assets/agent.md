# Introduction
The problem that we have is that the diskID provided by the IAAS does not correspond with the diskID on the vm as you can see in the related information part.
Therefore, we are trying to mitigate this issue by using diskIdTransformation as you can see in the example below

Do note that if this fails it will always fallback to other means of mounting the disk

## Disk ID transform rules
the following 2 json entries
```
"DiskIDTransformPattern": "^d-(.+)$",
"DiskIDTransformReplacement": "virtio-${1}"
```

## what it does
the `DiskIDTransformPattern` will match `d-gw8ibkvqdrmdqzwpo4rk` in to 2 groups `d-` and `gw8ibkvqdrmdqzwpo4rk`
the `DiskIDTransformReplacement` will match and replace `gw8ibkvqdrmdqzwpo4rk` with `virtio-gw8a1q0dqyqmcjrnetpj`

the agent will then glob and mount `/dev/disk/by-id/virtio-gw8a1q0dqyqmcjrnetpj`

## related information
contents of `persistent_disk_hints.json`
```
{
  "d-gw8ibkvqdrmdqzwpo4rk": {
    "ID": "d-gw8ibkvqdrmdqzwpo4rk",
    "DeviceID": "",
    "VolumeID": "/dev/disk/by-id/virtio-gw8ibkvqdrmdqzwpo4rk",
    "Lun": "",
    "HostDeviceID": "",
    "Path": "/dev/disk/by-id/virtio-gw8ibkvqdrmdqzwpo4rk",
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
virtio-gw8a1q0dqyqmcjrnetpj
virtio-gw8a1q0dqyqmcjrnetpj-part1
virtio-gw8a1q0dqyqmcjrnetpj-part2
virtio-gw8au7up14j66ge6u4vs
virtio-gw8au7up14j66ge6u4vs-part1
virtio-gw8ibkvqdrmdqzwpo4rk
virtio-gw8ibkvqdrmdqzwpo4rk-part1
```