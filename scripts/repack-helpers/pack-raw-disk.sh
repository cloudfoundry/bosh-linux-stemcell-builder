#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< "raw-disk-path"'
  exit 2
fi

raw_disk_path=$(cat)

output_image=$(mktemp -d)

pushd $(dirname ${raw_disk_path}) > /dev/null
tar czf ${output_image}/image $(basename ${raw_disk_path})
popd > /dev/null

echo ${output_image}/image
