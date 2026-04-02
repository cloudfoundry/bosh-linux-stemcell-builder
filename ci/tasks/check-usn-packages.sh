#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

source "${REPO_ROOT}/ci/tasks/usn-processing/usn-shared-functions.sh"

process_usns "${REPO_PARENT}/usn-log-in/usn-log.json" "${REPO_PARENT}/usn-gh-json/usn"


if [ "$ALL_PACKAGE_VERSIONS_AVAILABLE" != true ]
then
  echo "Not all vulnerable packages have available fixes yet, deferring stemcell build."
  exit 1
else
  exit 0
fi
