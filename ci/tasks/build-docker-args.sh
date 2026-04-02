#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

cat << EOF > "${REPO_PARENT}/docker-build-args/docker-build-args.json"
{
  "SYFT_VERSION": "$(cat "${REPO_PARENT}/syft-github-release/tag")",
  "placeholder": "without trailing comma"
}
EOF

cat "${REPO_PARENT}/docker-build-args/docker-build-args.json"
