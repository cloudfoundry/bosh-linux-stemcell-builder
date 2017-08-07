#!/bin/bash

set -e -x

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )
stemcell=$(realpath stemcell/*.tgz)

echo -e "Check if the stemcell ${VERSION} already exists on file.w3.ibm.com"
curl http://file.w3.bluemix.net/releases/light-bosh-stemcell/${VERSION}/ | grep "200 OK"
if [[ $? != 0 ]]; then
  echo -e "The stemcell ${VERSION} already exists at http://file.w3.bluemix.net/releases/light-bosh-stemcell/${VERSION}, exiting..."
  exit 1
fi

mkdir -p light-bosh-stecmcell/publish/${VERSION}
echo $FILE_W3_STEMCELL_PEM > light-bosh-stecmcell/light-bosh-stecmcell.pem
cp ${stemcell} light-bosh-stecmcell/publish/${VERSION}/
cd light-bosh-stecmcell
scp -o "StrictHostKeyChecking no" -i light-bosh-stecmcell.pem -r publish/${VERSION} light-bosh-stemcell@file.w3.bluemix.net:~/repo
if [[ $? != 0 ]]; then
  echo -e "Uploading the light stemcell failed"
  exit 1
fi

echo "Done"
