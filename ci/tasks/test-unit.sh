#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

os_image="$(readlink -f "${REPO_PARENT}"/os-image-tarball/*.tgz)"

# we need sudo for our chroot operations in the shellout_types tests
apt install sudo

pushd "${REPO_PARENT}/bosh-linux-stemcell-builder/bosh-stemcell"
  bundle install
  bundle exec rake spec
  OS_IMAGE="${os_image}" bundle exec rake spec:shellout_types
popd
