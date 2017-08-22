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
check_param BOSHIO_TOKEN

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

echo -e "\n[INFO] Calculating light stemcell checksum..."
FILE=light-bosh-stemcell-${VERSION}-softlayer-xen-ubuntu-trusty-go_agent.tgz
FILE_URL=https://s3.amazonaws.com/${PUBLISHED_BUCKET_NAME}/light-bosh-stemcell-${VERSION}-softlayer-xen-ubuntu-trusty-go_agent.tgz

if curl -L ${FILE_URL} > /dev/null ; then
  CHECKSUM=`curl -L ${FILE_URL} | sha1sum | cut -d " " -f 1`
else
  echo -e "\n[WARNING] Bucket return error, skipping publish checksum."
  exit 1
fi

if [ -n "${BOSHIO_TOKEN}" ]; then
  echo -e "\n[INFO] Posting light stemcell checksum to bosh.io."
  curl -X POST \
    --fail \
    -d "sha1=${CHECKSUM}" \
    -H "Authorization: bearer ${BOSHIO_TOKEN}" \
    "https://bosh.io/checksums/${FILE}"
else
  echo -e "\n[ERROR] BOSHIO_TOKEN not provided, skipping publish checksum."
  exit 1
fi
