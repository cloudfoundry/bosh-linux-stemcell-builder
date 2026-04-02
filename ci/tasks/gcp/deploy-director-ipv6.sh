#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

cat > "${REPO_PARENT}/director-creds.yml" <<EOF
internal_ip: ${INTERNAL_IP}
EOF

cat > "${REPO_PARENT}/director-vars.yml" <<EOF
project_id: ${GCP_PROJECT_ID}
zone: ${GCP_ZONE}
preemptible: ${GCP_PREEMPTIBLE}
tags: [${TAG}]
EOF

cat > "${REPO_PARENT}/network-variables.yml" <<EOF
director_name: stemcell-smoke-tests-director
internal_cidr: ${INTERNAL_CIDR}
internal_gw: ${INTERNAL_GW}
network:    ${GCP_NETWORK_NAME}
subnetwork: ${GCP_SUBNET_NAME}
reserved_range: [${RESERVED_RANGE}]
second_internal_cidr: ${SECOND_INTERNAL_CIDR}
second_internal_gw: ${SECOND_INTERNAL_GW}
second_internal_ip: ${SECOND_INTERNAL_IP}
EOF

echo ${GCP_JSON_KEY} > "${REPO_PARENT}/gcp_creds.json"

bosh interpolate "${REPO_PARENT}/bosh-deployment/bosh.yml" \
  -o "${REPO_PARENT}/bosh-deployment/gcp/cpi.yml" \
  -o "${REPO_PARENT}/bosh-deployment/jumpbox-user.yml" \
  -o "${REPO_PARENT}/bosh-deployment/misc/ipv6/bosh.yml" \
  -o "${REPO_PARENT}/bosh-deployment/misc/second-network.yml" \
  -o "${REPO_ROOT}/ops-files/ipv6-director.yml" \
  --vars-store "${REPO_PARENT}/director-creds.yml" \
  --vars-file "${REPO_PARENT}/director-vars.yml" \
  --var-file gcp_credentials_json="${REPO_PARENT}/gcp_creds.json" \
  --vars-file "${REPO_PARENT}/network-variables.yml" > "${REPO_PARENT}/director.yml"

set +e
bosh create-env "${REPO_PARENT}/director.yml" -l "${REPO_PARENT}/director-creds.yml"
deployed=$?
cp -r $HOME/.bosh "${REPO_PARENT}/director-state/"
cp "${REPO_PARENT}/director.yml" "${REPO_PARENT}/director-creds.yml" "${REPO_PARENT}/director-state.json" "${REPO_PARENT}/director-state/"
if [ $deployed -ne 0 ]
then
  exit 1
fi
set -e

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`bosh int "${REPO_PARENT}/director-creds.yml" --path /internal_ip`
export BOSH_CA_CERT=`bosh int "${REPO_PARENT}/director-creds.yml" --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "${REPO_PARENT}/director-creds.yml" --path /admin_password`

bosh -n update-cloud-config "${REPO_PARENT}/bosh-deployment/gcp/cloud-config.yml" \
          --ops-file "${REPO_ROOT}/ops-files/reserve-ips.yml" \
          --ops-file "${REPO_ROOT}/ops-files/disable-ephemeral-ip.yml" \
          --ops-file "${REPO_ROOT}/ops-files/ipv6-cc.yml" \
          --ops-file "${REPO_ROOT}/ops-files/resource-pool-cc.yml" \
          --vars-file "${REPO_PARENT}/network-variables.yml" \
          --vars-file "${REPO_PARENT}/director-vars.yml"
