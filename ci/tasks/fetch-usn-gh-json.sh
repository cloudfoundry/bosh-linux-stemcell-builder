#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

GIT_URI="https://github.com/canonical/ubuntu-security-notices.git"
GIT_BRANCH="main"
CACHE_REPO="${REPO_PARENT}/usn-gh-json-cache/repo"
OUTPUT_DIR="${REPO_PARENT}/usn-gh-json"

# Partial (blobless) + shallow + sparse clone: only the usn/ directory's
# blobs are ever fetched, never osv/ or vex/ (which dwarf usn/ in size).
# Cached across builds of this job/step (same worker) so warm runs only
# fetch blobs for files that actually changed since the last run.
if [[ -d "${CACHE_REPO}/.git" ]]; then
  echo "cache hit: fetching latest ${GIT_BRANCH}..."
  # Re-assert sparse-checkout config every run: it's a no-op when already
  # correct, but self-heals a cache left without it by a run that was
  # killed between `clone` and `sparse-checkout set` completing - without
  # this, `reset --hard` below would silently fetch all of vex/ and osv/
  # (33GB+) since --filter=blob:none only defers blob fetch, it doesn't
  # skip it.
  git -C "${CACHE_REPO}" sparse-checkout init --cone
  git -C "${CACHE_REPO}" sparse-checkout set usn
  git -C "${CACHE_REPO}" fetch --depth 1 origin "${GIT_BRANCH}"
  git -C "${CACHE_REPO}" reset --hard "origin/${GIT_BRANCH}"
else
  echo "cache miss: performing partial clone of ${GIT_URI}..."
  mkdir -p "$(dirname "${CACHE_REPO}")"
  git clone --filter=blob:none --depth 1 --no-checkout --branch "${GIT_BRANCH}" "${GIT_URI}" "${CACHE_REPO}"
  git -C "${CACHE_REPO}" sparse-checkout init --cone
  git -C "${CACHE_REPO}" sparse-checkout set usn
  # `sparse-checkout set` above already materializes the working tree;
  # this checkout just confirms HEAD is on the right branch (prints
  # "Already on '<branch>'" - that's expected, not a bug).
  git -C "${CACHE_REPO}" checkout "${GIT_BRANCH}"
fi

mkdir -p "${OUTPUT_DIR}/usn"
rsync -a "${CACHE_REPO}/usn/" "${OUTPUT_DIR}/usn/"
