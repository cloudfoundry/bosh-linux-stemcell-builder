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
existing_subnet_name="$(gcloud compute networks subnets list \
    --regions="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --filter="name=('${SUBNET_NAME}')" \
    --format='value(name)' \
    2>"${gcloud_stderr}")" && subnet_lookup_ok=true || subnet_lookup_ok=false

if ${subnet_lookup_ok}; then
  if [[ -n "${existing_subnet_name}" ]]; then
    current_subnet="$(gcloud compute networks subnets describe "${SUBNET_NAME}" \
        --region="${GCP_REGION}" \
        --project="${GCP_PROJECT_ID}" \
        --format='csv[no-heading](network.basename(),ipCidrRange,privateIpGoogleAccess,stackType)' \
        2>"${gcloud_stderr}")"
    expected_subnet="${GCP_NETWORK_NAME},${SUBNET_CIDR},True,IPV4_ONLY"
    if [[ "${current_subnet}" != "${expected_subnet}" ]]; then
      echo "ERROR: Subnet '${SUBNET_NAME}' exists but is misconfigured."
      echo "  Expected: ${expected_subnet}"
      echo "  Actual:   ${current_subnet}"
      exit 1
    fi
    echo "Subnet '${SUBNET_NAME}' already exists and matches expected configuration."
  else
    echo "Creating subnet '${SUBNET_NAME}'..."
    gcloud compute networks subnets create "${SUBNET_NAME}" \
      --network="${GCP_NETWORK_NAME}" \
      --region="${GCP_REGION}" \
      --range="${SUBNET_CIDR}" \
      --enable-private-ip-google-access \
      --stack-type=IPV4_ONLY \
      --project="${GCP_PROJECT_ID}"
    echo "Subnet '${SUBNET_NAME}' created."
  fi
else
  echo "ERROR: gcloud subnet lookup failed for subnet '${SUBNET_NAME}':"
  cat "${gcloud_stderr}" >&2
  exit 1
fi

echo "Checking for firewall rule '${SUBNET_NAME}'..."
existing_fw_name="$(gcloud compute firewall-rules list \
    --project="${GCP_PROJECT_ID}" \
    --filter="name=('${SUBNET_NAME}')" \
    --format='value(name)' \
    2>"${gcloud_stderr}")" && fw_lookup_ok=true || fw_lookup_ok=false

if ${fw_lookup_ok}; then
  if [[ -n "${existing_fw_name}" ]]; then
    current_fw_json="$(gcloud compute firewall-rules describe "${SUBNET_NAME}" \
        --project="${GCP_PROJECT_ID}" \
        --format=json \
        2>"${gcloud_stderr}")"

    # Validate network, direction, disabled
    actual_network="$(echo "${current_fw_json}" | jq -r '.network | split("/") | last')"
    actual_direction="$(echo "${current_fw_json}" | jq -r '.direction')"
    actual_disabled="$(echo "${current_fw_json}" | jq -r '.disabled')"

    if [[ "${actual_network}" != "${GCP_NETWORK_NAME}" ]] || \
       [[ "${actual_direction}" != "INGRESS" ]] || \
       [[ "${actual_disabled}" != "false" ]]; then
      echo "ERROR: Firewall rule '${SUBNET_NAME}' exists but is misconfigured."
      echo "  Expected network=${GCP_NETWORK_NAME}, direction=INGRESS, disabled=false"
      echo "  Actual   network=${actual_network}, direction=${actual_direction}, disabled=${actual_disabled}"
      exit 1
    fi

    # Validate allowed (should be exactly [{IPProtocol: "all"}])
    actual_allowed="$(echo "${current_fw_json}" | jq -c '[.allowed[] | {protocol: .IPProtocol, ports: (.ports // [])}] | sort_by(.protocol)')"
    expected_allowed='[{"protocol":"all","ports":[]}]'
    if [[ "${actual_allowed}" != "${expected_allowed}" ]]; then
      echo "ERROR: Firewall rule '${SUBNET_NAME}' has wrong allowed configuration."
      echo "  Expected: ${expected_allowed}"
      echo "  Actual:   ${actual_allowed}"
      exit 1
    fi

    # Validate sourceRanges (should be exactly the subnet CIDR)
    actual_ranges="$(echo "${current_fw_json}" | jq -c '(.sourceRanges // []) | sort')"
    expected_ranges="$(printf '["%s"]' "${SUBNET_CIDR}")"
    if [[ "${actual_ranges}" != "${expected_ranges}" ]]; then
      echo "ERROR: Firewall rule '${SUBNET_NAME}' has wrong source ranges."
      echo "  Expected: ${expected_ranges}"
      echo "  Actual:   ${actual_ranges}"
      exit 1
    fi

    # Validate targetTags (order-insensitive)
    actual_tags="$(echo "${current_fw_json}" | jq -c '(.targetTags // []) | sort')"
    expected_tags="$(printf '%s\n' ${FIREWALL_TAGS//,/ } | jq -R . | jq -sc 'sort')"
    if [[ "${actual_tags}" != "${expected_tags}" ]]; then
      echo "ERROR: Firewall rule '${SUBNET_NAME}' has wrong target tags."
      echo "  Expected: ${expected_tags}"
      echo "  Actual:   ${actual_tags}"
      exit 1
    fi

    echo "Firewall rule '${SUBNET_NAME}' already exists and matches expected configuration."
  else
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
  fi
else
  echo "ERROR: gcloud firewall-rules lookup failed for '${SUBNET_NAME}':"
  cat "${gcloud_stderr}" >&2
  exit 1
fi

echo "Integration network '${SUBNET_NAME}' is ready."
