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

version=$( cat "${REPO_PARENT}/bosh-agent/.resource/version" )

cp "${REPO_PARENT}/bosh-agent/.resource/metalink.meta4" "${REPO_PARENT}/bosh-linux-stemcell-builder-out/stemcell_builder/stages/bosh_go_agent/assets/"
cp "${REPO_PARENT}/bosh-agent/.resource/version" "${REPO_PARENT}/bosh-linux-stemcell-builder-out/stemcell_builder/stages/bosh_go_agent/assets/bosh-agent-version"

pushd "${REPO_PARENT}/bosh-linux-stemcell-builder-out"
	if [ "$(git status --porcelain)" != "" ]; then
		git add -A
		git config --global user.email "ci@localhost"
		git config --global user.name "CI Bot"
		git commit -m "bump bosh-agent/$version"
	fi
popd
