#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

# we need sudo for our chroot operations in the shellout_types tests
apt install sudo

pushd "${REPO_PARENT}/bosh-linux-stemcell-builder"
  bundle install --local

  pushd bosh-stemcell
    bundle exec rspec spec/
    OS_IMAGE="$(readlink -f ../../os-image-tarball/*.tgz)" bundle exec rspec spec/ --tag shellout_types
  popd
popd
