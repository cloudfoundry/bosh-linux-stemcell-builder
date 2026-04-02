#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

git clone "${REPO_PARENT}/bosh-linux-stemcell-builder" "${REPO_PARENT}/bosh-linux-stemcell-builder-out"

url=$(cat "${REPO_PARENT}/bosh-blobstore-cli/url")
version=$(cat "${REPO_PARENT}/bosh-blobstore-cli/version")
sha256sum=$(sha256sum -b "${REPO_PARENT}/bosh-blobstore-cli"/*cli* | awk '{print $1}')

echo "${url}" > \
  "${REPO_PARENT}/bosh-linux-stemcell-builder-out/stemcell_builder/stages/blobstore_clis/assets/bosh-blobstore-${BLOBSTORE_TYPE}.url"
echo "${version}" > \
  "${REPO_PARENT}/bosh-linux-stemcell-builder-out/stemcell_builder/stages/blobstore_clis/assets/bosh-blobstore-${BLOBSTORE_TYPE}.version"
echo "${sha256sum}" > \
  "${REPO_PARENT}/bosh-linux-stemcell-builder-out/stemcell_builder/stages/blobstore_clis/assets/bosh-blobstore-${BLOBSTORE_TYPE}.sha256sum"

pushd "${REPO_PARENT}/bosh-linux-stemcell-builder-out"
  if [ "$(git status --porcelain)" != "" ]; then
    git add -A
    git config --global user.email "ci@localhost"
    git config --global user.name "CI Bot"
    git commit -m "bump bosh-blobstore-${BLOBSTORE_TYPE}/${version}"
  fi
popd
