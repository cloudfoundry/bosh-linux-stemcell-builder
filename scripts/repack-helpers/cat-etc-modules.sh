#!/bin/bash -eux

path=$(dirname $0)

if [[ $# != 2 ]];then
  echo "USAGE: $0 [stemcell] [version]"
fi

stemcell=$1
version=$2

stemcell_path=$($path/extract-stemcell.sh $stemcell)
pushd $GOPATH/src/github.com/cloudfoundry/bosh-agent/
  ./bin/build-linux-amd64
popd

raw_image=$(echo $stemcell_path | \
  $path/extract-image.sh | \
  $path/mount-image.sh | \
  $path/update-file.sh $GOPATH/src/github.com/cloudfoundry/bosh-agent/out/bosh-agent /var/vcap/bosh/bin/bosh-agent | \
  $path/run-in-chroot.sh cat /etc/modules | \
  $path/unmount-image.sh)

$path/pack-stemcell.sh $stemcell_path $raw_image $version
