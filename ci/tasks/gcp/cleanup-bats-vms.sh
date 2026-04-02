#!/usr/bin/env bash
set -eu -o pipefail

: "${GCP_JSON_KEY:?}"
: "${GCP_PROJECT_ID:?}"
: "${GCP_ZONE:?}"
: "${GCP_SUBNET_NAME:?}"
: "${TAG:?}"

echo "${GCP_JSON_KEY}" | gcloud auth activate-service-account --key-file - --project "${GCP_PROJECT_ID}"

echo "Looking for leftover VMs on subnet '${GCP_SUBNET_NAME}' with tag '${TAG}' in zone '${GCP_ZONE}'..."

vms=$(gcloud compute instances list \
  --filter="zone:${GCP_ZONE} AND networkInterfaces.subnetwork:${GCP_SUBNET_NAME} AND tags.items=${TAG}" \
  --format="value(name)")

if [[ -z "${vms}" ]]; then
  echo "No leftover VMs found."
  exit 0
fi

echo "Found VMs to delete:"
echo "${vms}"

for vm in ${vms}; do
  echo "Deleting ${vm}..."
  gcloud compute instances delete "${vm}" --zone="${GCP_ZONE}" -q
done

echo "Cleanup complete."
