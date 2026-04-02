#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

# add the new usn to the list of unfound usns
touch "${REPO_PARENT}/joined-usns"
cp "${REPO_PARENT}/unfound-usns/usns.json" "${REPO_PARENT}/joined-usns"
cat "${REPO_PARENT}/usn/usn.json" >> "${REPO_PARENT}/joined-usns"

# turn the unfound usns into an array
mapfile -t UNFOUND_USNS < "${REPO_PARENT}/joined-usns"

# check if each of the unfound usns is in github
touch "${REPO_PARENT}/found-usns/usns.json"
touch "${REPO_PARENT}/updated-unfound-usns/usns.json"
for usn in "${UNFOUND_USNS[@]}"; do
    id=$(echo $usn | jq -r '.url' | cut -d '/' -f6 | cut -d '-' -f2,3)
    echo "checking for USN-${id} in github..."

    if [[ -f "${REPO_PARENT}/usn-gh-json/usn/${id}.json" ]]; then
        echo "found ${id}.json "
        echo $usn >> "${REPO_PARENT}/found-usns/usns.json"
    else
        echo "${id}.json not found"
        echo $usn >> "${REPO_PARENT}/updated-unfound-usns/usns.json"
    fi
done