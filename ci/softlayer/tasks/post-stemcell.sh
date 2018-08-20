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

git clone stemcells-index stemcells-index-output

cp stemcell/*.tgz stemcells-index/

echo -e "\n[INFO] Generate light stemcell metalink record."
pushd stemcells-index
  stemcell_name=light-bosh-stemcell-${VERSION}-softlayer-xen-ubuntu-${OS_VERSION}-go_agent
  file_url=https://s3.amazonaws.com/${PUBLISHED_BUCKET_NAME}/${stemcell_name}.tgz
  stemcell_filename="${stemcell_name}.tgz"

  meta4_path=./dev/$OS_NAME-$OS_VERSION/$VERSION/$stemcell_name.meta4

  mkdir -p "$( dirname "$meta4_path" )"
  meta4 create --metalink="$meta4_path"

  echo -e "\n[INFO] Import light stemcell file(include hash generation)..."
  meta4 import-file --metalink="$meta4_path" --version="$VERSION" "${stemcell_filename}"

  echo -e "\n[INFO] Set light stemcell url..."
  meta4 file-set-url --metalink="$meta4_path" --file="${stemcell_filename}" "${file_url}"

  # just in case we need to debug/verify the live results
  echo -e "\n[INFO] Generated light stemcell meta4 file:"
  cat "$meta4_path"
popd

echo -e "\n[INFO] Merge light stemcell metalink records."
cd stemcells-index-output

meta4_path=./published/$OS_NAME-$OS_VERSION/$VERSION/stemcells.meta4

mkdir -p "$( dirname "$meta4_path" )"
meta4 create --metalink="$meta4_path"

find ../stemcells-index/dev/$OS_NAME-$OS_VERSION/$VERSION -name *.meta4 \
  | xargs -n1 -- meta4 import-metalink --metalink="$meta4_path"

echo -e "\n[INFO] Merged light stemcell meta4 file:"
cat "$meta4_path"

echo -e "\n[INFO] Push to stemcells-index repo."
git add -A
git config --global user.email "ci@localhost"
git config --global user.name "CI Bot"
git commit -m "publish: $OS_NAME-$OS_VERSION/$VERSION"