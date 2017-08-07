#!/bin/bash

set -e

mkdir -p light-bluemix-stemcell-prod
cp light-bluemix-stemcell/*.tgz light-bluemix-stemcell-prod/

fileUrl=https://s3-api.us-geo.objectstorage.softlayer.net/${PUBLISHED_BUCKET_NAME}/${file}
echo -e "Stemcell Download URL -> ${fileUrl}"
checksum=`curl -L ${fileUrl} | sha1sum | cut -d " " -f 1`
echo -e "Sha1 hashcode -> $checksum"

echo "Done"
