#!/bin/bash

set -e

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )
stemcell=$(realpath stemcell/*.tgz)

echo -e "[INFO] Install dependencies"
apt-get update
apt-get install openssh-server -y

#echo -e "[INFO]Check if the stemcell ${VERSION} already exists on file.w3.ibm.com"
#set +e
#response=$(curl --write-out %{http_code} --silent --output /dev/null http://file.w3.bluemix.net/releases/light-bosh-stemcell/${VERSION}/)
#if [[ "$response" == "200" ]]; then
#  echo -e "The stemcell ${VERSION} already exists at http://file.w3.bluemix.net/releases/light-bosh-stemcell/${VERSION}, exiting..."
#  exit 1
#elif [[ "$response" == "000" ]]; then
#    echo -e "\n\033[31m[WARN] Time out to connect to file.w3.bluemix.net. Try to add static host ip.\033[0m"
#    echo "10.106.192.96 file.w3.bluemix.net" >> /etc/hosts
#    response=$(curl --write-out %{http_code} --silent --output /dev/null http://file.w3.bluemix.net/releases/light-bosh-stemcell/${VERSION}/)
#    if [[ "$response" == "200" ]]; then
#      echo -e "The stemcell ${VERSION} already exists at http://file.w3.bluemix.net/releases/light-bosh-stemcell/${VERSION}, exiting..."
#      exit 1
#    fi
#fi
#set -e

mkdir -p light-bosh-stecmcell/publish/${VERSION}
echo $FILE_W3_STEMCELL_PEM > light-bosh-stecmcell/light-bosh-stecmcell.pem
chmod 400 light-bosh-stecmcell/light-bosh-stecmcell.pem
cp ${stemcell} light-bosh-stecmcell/publish/${VERSION}/
cd light-bosh-stecmcell
scp -o "StrictHostKeyChecking no" -i light-bosh-stecmcell.pem -r publish/${VERSION} light-bosh-stemcell@file.w3.bluemix.net:~/repo
if [[ $? != 0 ]]; then
  echo -e "Uploading the light stemcell failed"
  exit 1
fi

echo "Done"
