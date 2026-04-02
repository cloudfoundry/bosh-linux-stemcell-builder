#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

mv "${REPO_PARENT}"/director-state/* "${REPO_PARENT}/"
mv "${REPO_PARENT}/director-state/.bosh" "${HOME}/"

export BOSH_ENVIRONMENT=`bosh int "${REPO_PARENT}/director-creds.yml" --path /internal_ip`
export BOSH_CA_CERT=`bosh int "${REPO_PARENT}/director-creds.yml" --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "${REPO_PARENT}/director-creds.yml" --path /admin_password`

bosh deployments --column name | xargs -n1 -I % "bosh" -n -d % delete-deployment
bosh clean-up -n --all
bosh delete-env "${REPO_PARENT}/director.yml" -l "${REPO_PARENT}/director-creds.yml"
