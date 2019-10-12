#!/bin/bash -eux

if [ -t 0 ]; then
  echo 'USAGE: $0 <<< extracted-stemcell-directory'
  exit 2
fi

input_stemcell=$(cat)

extracted_image_path=$(mktemp -d)

tar -xzf ${input_stemcell}/image -C ${extracted_image_path}

echo $extracted_image_path
