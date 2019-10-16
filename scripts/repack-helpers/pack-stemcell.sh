#!/bin/bash -eux

if [ $# != 3 ]; then
  echo 'USAGE: $0 extracted-stemcell-path image-path version'
  exit 2
fi

extracted_stemcell_path=$1
image_path=$2
VERSION=$3

output_stemcell=$(mktemp -d)

cp ${image_path} ${extracted_stemcell_path}/image
pushd ${extracted_stemcell_path} >/dev/null
  sed -i -e "/^version:/d" stemcell.MF
  echo "version: $VERSION" >> stemcell.MF
  tar czf ${output_stemcell}/stemcell.tgz *
popd >/dev/null

echo ${output_stemcell}
