#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

cd "${REPO_PARENT}/bosh-linux-stemcell-builder"

function check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}
check_param OPERATING_SYSTEM_NAME
check_param OPERATING_SYSTEM_VERSION

OS_IMAGE_NAME=${OPERATING_SYSTEM_NAME}-${OPERATING_SYSTEM_VERSION}
OS_IMAGE=${REPO_PARENT}/os-image/${OS_IMAGE_NAME}.tgz
if [ -f "${REPO_PARENT}/build-time/timestamp" ]; then
  build_time="$(cat "${REPO_PARENT}/build-time/timestamp")"
  export BUILD_TIME="$(date --date "${build_time%.*}" +%Y%m%dT%H%M%SZ)"
fi

sudo chown -R ubuntu .
sudo chown -R ubuntu:ubuntu /mnt
sudo chmod u+s $(which sudo)
sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
case $OPERATING_SYSTEM_VERSION
in
# Because of the difference in build environments between Xenial and other Ubuntu stemcell lines (currently only Jammy)
# we must run 'bundle install' as the root user for it to function correctly.
"xenial")
    sudo bundle install --local
    ;;
*)
    bundle install --local
    ;;
esac
    bundle exec rake stemcell:build_os_image[$OPERATING_SYSTEM_NAME,$OPERATING_SYSTEM_VERSION,$OS_IMAGE]
SUDO
