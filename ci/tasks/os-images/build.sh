#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

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

chown -R ubuntu:ubuntu "${REPO_ROOT}" # ci resource
chown -R ubuntu:ubuntu "${REPO_PARENT}/bosh-linux-stemcell-builder"
chown -R ubuntu:ubuntu /mnt
sudo chmod u+s "$(which sudo)"

# pass SHLVL or '~ubuntu/.bash_logout' will exit 1
sudo --set-home --user ubuntu \
  --preserve-env=GEM_HOME,SHLVL,BUILD_TIME,UBUNTU_ADVANTAGE_TOKEN,UBUNTU_DEBOOTSTRAP_MIRROR \
  -- /bin/bash --login <<SUDO
set -e

cd "${REPO_PARENT}/bosh-linux-stemcell-builder"
bundle install

bundle exec rake "stemcell:build_os_image[${OPERATING_SYSTEM_NAME},${OPERATING_SYSTEM_VERSION},${OS_IMAGE}]"
SUDO
