#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-stemcell-directory'
  exit 2
fi

input_folder=$(cat)

output_path=$(mktemp -d)

pushd $input_folder > /dev/null
  tar zcf ${output_path}/image .
popd > /dev/null

echo $output_path/image
