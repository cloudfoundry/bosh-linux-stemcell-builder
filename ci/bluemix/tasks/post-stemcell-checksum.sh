#!/bin/bash

set -e -x -u

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

echo "\n[INFO] Calculating light stemcell checksum..."
FILE=light-bosh-stemcell-${VERSION}-softlayer-xen-ubuntu-trusty-go_agent.tgz
FILE_URL=https://s3.amazonaws.com/${PUBLISHED_BUCKET_NAME}/light-bosh-stemcell-${VERSION}-softlayer-xen-ubuntu-trusty-go_agent.tgz
CHECKSUM=`curl -L ${FILE_URL} | sha1sum | cut -d " " -f 1`

if [ -n "${BOSHIO_TOKEN}" ]; then
  echo "\n[INFO] Posting light stemcell checksum to bosh.io."
  curl -X POST \
    --fail \
    -d "sha1=${CHECKSUM}" \
    -H "Authorization: bearer ${BOSHIO_TOKEN}" \
    "https://bosh.io/checksums/${FILE}"
else
  echo "\n[WARNING] BOSHIO_TOKEN not provided, skipping publish checksum."
fi