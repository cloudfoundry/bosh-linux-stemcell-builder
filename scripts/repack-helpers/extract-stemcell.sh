#!/bin/bash -eux

if [ $# != 1 ]; then
  echo "USAGE: extract-stemcell.sh [base-stemcell]"
  exit 2
fi

stemcell_path=$1

extracted_stemcell=$(mktemp -d)
tar -xzf ${stemcell_path} -C $extracted_stemcell
echo $extracted_stemcell
