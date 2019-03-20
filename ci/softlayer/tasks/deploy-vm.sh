#!/bin/bash

set -e -x -u

function check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo -e "\n[ERROR] environment variable $name must be set"
    exit 1
  fi
}

check_param PUBLISHED_BUCKET_NAME
check_param OS_NAME
check_param OS_VERSION

export TASK_DIR=$PWD
export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

echo "[INFO] Install dependencies packages"
apt-get update
apt-get install curl -y

tar zxvf stemcell/*.tgz  -C ./
image_id=`grep "virtual-disk-image-uuid:" stemcell.MF| cut -d ":" -f2 | sed 's/^[ \t]*//g' `

curl -X POST -d '{ \
  "parameters":[ \
         "FORCE", \
         { \
             "imageTemplateId": "$image_id" \
         } \
  ] \
 }' https://$SL_USERNAME:$SL_API_KEY@api.softlayer.com/rest/v3/SoftLayer_Virtual_Guest/74649319/reloadOperatingSystem.json

