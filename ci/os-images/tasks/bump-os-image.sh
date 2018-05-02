#!/bin/bash

set -eu

function main() {
  if [[ -z "${OS_NAME}" ]]; then
    echo "OS_NAME must be set"
    exit 1
  fi

  if [[ -z "${OS_VERSION}" ]]; then
    echo "OS_VERSION must be set"
    exit 1
  fi

  local metalink_relative="bosh-stemcell/image-metalinks/${OS_NAME}-${OS_VERSION}.meta4"
  local metalink="${PWD}/bosh-linux-stemcell-builder/${metalink_relative}"

  rm "${metalink}"
  meta4 create --metalink "${metalink}"
  meta4 import-file --metalink "${metalink}" "${PWD}"/image-tarball/*.tgz
  meta4 file-set-url --metalink "${metalink}" "$(cat "${PWD}/image-tarball/url")"
  cat "${metalink}"

  rsync -avzp bosh-linux-stemcell-builder/ bosh-linux-stemcell-builder-push

  pushd "${PWD}/bosh-linux-stemcell-builder-push"
    git add "${metalink_relative}"
    git config user.name "CI Bot"
    git config user.email "ci@localhost"
    git commit -m "Bump OS image for ${OS_NAME}-${OS_VERSION}"
  popd
}

main
