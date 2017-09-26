#!/bin/bash

set -e -x -u

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

echo "\n[INFO] Copying candicate stemcell to production stemcell"
cp stemcell/*.tgz light-softlayer-stemcell-prod/

fileUrl=https://s3.amazonaws.com/${CANDIDATE_BUCKET_NAME}/light-bosh-stemcell-${VERSION}-softlayer-xen-ubuntu-trusty-go_agent.tgz
checksum=`curl -L ${fileUrl} | sha1sum | cut -d " " -f 1`
echo -e "Sha1 hashcode -> $checksum"

echo "stable-${VERSION}" > version-tag/tag

echo "Done"