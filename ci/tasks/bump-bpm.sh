#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

git clone "${REPO_PARENT}/bosh-linux-stemcell-builder" \
  "${REPO_PARENT}/bosh-linux-stemcell-builder-out"

version=$( cat "${REPO_PARENT}/bpm-tarball-release/version" )
sha256="${REPO_PARENT}/bpm-tarball-release/bpm-${version}-linux-amd64.tar.gz.sha256"

# bpm-release attaches the tarball when it creates the release. Releases from
# before that have none.
if [ ! -f "${sha256}" ]; then
  echo "bpm v${version} has no system install tarball asset" >&2
  exit 1
fi

TARGET_DIR="${REPO_PARENT}/bosh-linux-stemcell-builder-out/stemcell_builder/stages/bosh_bpm/assets"

echo "${version}" > "${TARGET_DIR}/bpm-version"
cp "${sha256}" "${TARGET_DIR}/bpm.sha256"

pushd "${REPO_PARENT}/bosh-linux-stemcell-builder-out"
	if [ "$(git status --porcelain)" != "" ]; then
		git add -A
		git config --global user.email "${GIT_USER_EMAIL}"
		git config --global user.name "${GIT_USER_NAME}"
		git commit -m "bump bpm/$version"
	fi
popd
