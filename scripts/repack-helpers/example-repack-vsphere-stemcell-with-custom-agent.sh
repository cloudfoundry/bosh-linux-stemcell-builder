#!/bin/bash -eux

set -o pipefail

path=$(dirname $0)

if [[ $# != 2 ]];then
  echo "USAGE: $0 [stemcell] [version]"
fi

stemcell=$1
version=$2

stemcell_path=$($path/extract-stemcell.sh $stemcell)
pushd $GOPATH/src/github.com/cloudfoundry/bosh-agent/
  git co 5adb3576c8d2e21d14ae1379f656e7afacbaf66b
  ./bin/build-linux-amd64
popd

cleanup_dirs=$(mktemp)
cleanup() {
  for dir in $(cat $cleanup_dirs); do
    rm -rf $dir
  done
}

trap cleanup EXIT

image_path=$(echo $stemcell_path | \
  $path/extract-image.sh | \
  $path/convert-vmdk-to-raw.sh | \
  tee -a $cleanup_dirs | \
  $path/mount-image.sh | \
  $path/update-file.sh $GOPATH/src/github.com/cloudfoundry/bosh-agent/out/bosh-agent /var/vcap/bosh/bin/bosh-agent | \
  $path/run-in-chroot.sh sudo apt install ifupdown | \
  $path/run-in-chroot.sh sudo which ifup | \
  $path/unmount-image.sh | \
  tee -a $cleanup_dirs | \
  $path/convert-raw-to-vmdk.sh)

echo $image_path >> $cleanup_dirs

$path/pack-stemcell.sh $stemcell_path $image_path $version
