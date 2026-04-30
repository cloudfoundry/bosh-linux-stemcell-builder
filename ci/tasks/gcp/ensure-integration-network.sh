#!/usr/bin/env bash
set -eu -o pipefail

: "${GCP_JSON_KEY:?}"
: "${GCP_PROJECT_ID:?}"
: "${GCP_REGION:?}"
: "${GCP_NETWORK_NAME:?}"
: "${SUBNET_INT:?}"

echo "${GCP_JSON_KEY}" | gcloud auth activate-service-account --key-file - --project "${GCP_PROJECT_ID}"

SUBNET_NAME="stemcell-builder-integration-${SUBNET_INT}"
SUBNET_CIDR="10.100.${SUBNET_INT}.0/24"

# 'bat'                 => BATS created VM tag
# 'test-stemcells-bats' => director, and compilation VM tag
FIREWALL_TAGS="bat,test-stemcells-bats"

gcloud_stderr="$(mktemp)"
trap 'rm -f "${gcloud_stderr}"' EXIT

echo "Checking for subnet '${SUBNET_NAME}' in region '${GCP_REGION}'..."
current_subnet="$(gcloud compute networks subnets describe "${SUBNET_NAME}" \
    --region="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --format='csv[no-heading](network.basename(),ipCidrRange,privateIpGoogleAccess,stackType)' \
    2>"${gcloud_stderr}")" && subnet_exists=true || subnet_exists=false

if ${subnet_exists}; then
  expected_subnet="${GCP_NETWORK_NAME},${SUBNET_CIDR},True,IPV4_ONLY"
  if [[ "${current_subnet}" != "${expected_subnet}" ]]; then
    echo "ERROR: Subnet '${SUBNET_NAME}' exists but is misconfigured."
    echo "  Expected: ${expected_subnet}"
    echo "  Actual:   ${current_subnet}"
    exit 1
  fi
  echo "Subnet '${SUBNET_NAME}' already exists and matches expected configuration."
elif grep -q "was not found" "${gcloud_stderr}"; then
  echo "Creating subnet '${SUBNET_NAME}'..."
  gcloud compute networks subnets create "${SUBNET_NAME}" \
    --network="${GCP_NETWORK_NAME}" \
    --region="${GCP_REGION}" \
    --range="${SUBNET_CIDR}" \
    --enable-private-ip-google-access \
    --stack-type=IPV4_ONLY \
    --project="${GCP_PROJECT_ID}"
  echo "Subnet '${SUBNET_NAME}' created."
else
  echo "ERROR: gcloud describe failed for subnet '${SUBNET_NAME}':"
  cat "${gcloud_stderr}" >&2
  exit 1
fi

echo "Checking for firewall rule '${SUBNET_NAME}'..."
current_fw="$(gcloud compute firewall-rules describe "${SUBNET_NAME}" \
    --project="${GCP_PROJECT_ID}" \
    --format='csv[no-heading](network.basename(),direction,allowed[0].IPProtocol,sourceRanges[0],disabled)' \
    2>"${gcloud_stderr}")" && fw_exists=true || fw_exists=false

if ${fw_exists}; then
  expected_fw="${GCP_NETWORK_NAME},INGRESS,all,${SUBNET_CIDR},False"
  if [[ "${current_fw}" != "${expected_fw}" ]]; then
    echo "ERROR: Firewall rule '${SUBNET_NAME}' exists but is misconfigured."
    echo "  Expected: ${expected_fw}"
    echo "  Actual:   ${current_fw}"
    exit 1
  fi
  # Validate target tags independently; sort before comparing since order is not deterministic
  current_tags="$(gcloud compute firewall-rules describe "${SUBNET_NAME}" \
    --project="${GCP_PROJECT_ID}" \
    --format='value(targetTags.list())' \
    | tr ',;' '\n' | LC_ALL=C sort | tr '\n' ',' | sed 's/,$//')"
  expected_tags="$(printf '%s\n' ${FIREWALL_TAGS//,/ } | LC_ALL=C sort | tr '\n' ',' | sed 's/,$//')"
  if [[ "${current_tags}" != "${expected_tags}" ]]; then
    echo "ERROR: Firewall rule '${SUBNET_NAME}' has wrong target tags."
    echo "  Expected: ${expected_tags}"
    echo "  Actual:   ${current_tags}"
    exit 1
  fi
  echo "Firewall rule '${SUBNET_NAME}' already exists and matches expected configuration."
elif grep -q "was not found" "${gcloud_stderr}"; then
  echo "Creating firewall rule '${SUBNET_NAME}'..."
  gcloud compute firewall-rules create "${SUBNET_NAME}" \
    --network="${GCP_NETWORK_NAME}" \
    --project="${GCP_PROJECT_ID}" \
    --direction=INGRESS \
    --priority=1000 \
    --allow=all \
    --source-ranges="${SUBNET_CIDR}" \
    --target-tags="${FIREWALL_TAGS}"
  echo "Firewall rule '${SUBNET_NAME}' created."
else
  echo "ERROR: gcloud describe failed for firewall rule '${SUBNET_NAME}':"
  cat "${gcloud_stderr}" >&2
  exit 1
fi

echo "Integration network '${SUBNET_NAME}' is ready."
