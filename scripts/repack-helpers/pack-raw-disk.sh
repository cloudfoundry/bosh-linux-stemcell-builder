#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< "raw-disk-path"'
  exit 2
fi

raw_disk_path=$(cat)

output_image=$(mktemp -d)

pushd ${raw_disk_path%disk.raw} > /dev/null
  tar czf ${output_image}/image disk.raw
popd > /dev/null

echo ${output_image}
