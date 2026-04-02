#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

# env
: ${SSH_PRIVATE_KEY:?}
: ${GCE_CREDENTIALS_JSON:?}


mkdir -p "${REPO_PARENT}/deployment-state/assets/"
cp "${REPO_PARENT}"/bosh-cpi-release/*.tgz "${REPO_PARENT}/deployment-state/assets/cpi.tgz"
cp "${REPO_PARENT}"/light-stemcell/*.tgz "${REPO_PARENT}/deployment-state/assets/stemcell.tgz"

mbus_password="$(openssl rand -base64 24 | tr -d '[/+]')"
gce_cloud_provider_mbus="https://mbus:${mbus_password}@$(jq -r .skeletal_external_ip "${REPO_PARENT}/terraform/metadata"):6868"
gce_cloud_provider_agent_mbus="https://mbus:${mbus_password}@0.0.0.0:6868"

pushd "${REPO_PARENT}/deployment-state" > /dev/null
  echo "Deploying skeletal instance..."

  echo "${SSH_PRIVATE_KEY}" > bosh.pem # CLI has trouble with newlines in variable

  bosh -n interpolate \
    -v gce_cloud_provider_mbus="${gce_cloud_provider_mbus}" \
    -v gce_cloud_provider_agent_mbus="${gce_cloud_provider_agent_mbus}" \
    -v gce_credentials_json="'${GCE_CREDENTIALS_JSON}'" \
    -v ssh_private_key="bosh.pem" \
    -l "${REPO_PARENT}/terraform/metadata" \
    --vars-store=./skeletal-deployment-vars.yml \
    "${REPO_ROOT}/ci/tasks/light-google/skeletal-deployment.yml" > ./skeletal-deployment.yml

  bosh -n create-env ./skeletal-deployment.yml
popd > /dev/null

echo "Successfully deployed!"
