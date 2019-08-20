#!/bin/bash -eux

if [ $# != 3 ]; then
  echo 'USAGE: $0 extracted-stemcell-path raw-disk-path version'
  exit 2
fi

extracted_stemcell_path=$1
raw_disk_path=$2
VERSION=$3

output_stemcell=$(mktemp -d)

pushd ${raw_disk_path%disk.raw}
  tar czf ${extracted_stemcell_path}/image disk.raw
popd
pushd ${extracted_stemcell_path}
  sed -i -e "/version:/d" stemcell.MF
  echo "version: $VERSION" >> stemcell.MF
  tar czf ${output_stemcell}/stemcell.tgz *
popd

echo "DONE..."
echo "Your stemcell can be found at: ${output_stemcell}/stemcell.tgz"
