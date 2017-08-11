#!/bin/bash

set -e -x -u

pushd stemcell
  echo "\n[INFO] Unpacking stemcell raw tgz."
  stemcell_filename=`ls light*.tgz`
  tar -zxvf *.tgz

  echo "\n[INFO] Replacing stemcell files."
  sed -i 's/bluemix/softlayer/g' stemcell.MF
  rm -rf *.tgz
  tar -zcvf ${stemcell_filename} image *.*
popd

echo "\n[INFO] Renaming and moving stemcell file."
rename 's/bluemix/softlayer/' stemcell/*.tgz
mv stemcell/*.tgz replaced/
