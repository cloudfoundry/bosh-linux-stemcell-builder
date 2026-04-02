#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

: ${PROJECT_NAME:?}
: ${GCP_SERVICE_ACCOUNT_KEY:?}

echo "Creating light stemcell..."

set -e
original_stemcell="$(echo "${REPO_PARENT}"/stemcell/*.tgz)"
original_stemcell_name="$(basename "${original_stemcell}")"
light_stemcell_name="light-${original_stemcell_name}"

raw_stemcell="$(echo "${REPO_PARENT}"/base-oss-google-ubuntu-stemcell/*.gz)"
raw_stemcell_filename="$(basename "${raw_stemcell}")"

raw_stemcell_uri="$(cat "${REPO_PARENT}/base-oss-google-ubuntu-stemcell/url")"

image_name=$(echo "$raw_stemcell_filename" | sed -e 's/[^0-9a-zA-Z]/-/g' -e 's/-tar-gz$//' -e 's/-go-agent-raw//' -e 's/^bosh-//')

# authenticate with service account
echo ${GCP_SERVICE_ACCOUNT_KEY} | gcloud auth activate-service-account --key-file - --project ${PROJECT_NAME}

guest_os_features=()
if [[ "${EFI:-false}" == "true" ]]; then
  guest_os_features+=("UEFI_COMPATIBLE")
fi
if [[ "${GVNIC:-true}" == "true" ]]; then
  guest_os_features+=("GVNIC")
fi

guest_os_features_flag=""
if (( ${#guest_os_features[@]} > 0 )); then
  printf -v guest_os_features_joined '%s,' "${guest_os_features[@]}"
  guest_os_features_flag="--guest-os-features=${guest_os_features_joined%,}"
fi

# create image
gcloud compute images create "${image_name}" \
 --project="${PROJECT_NAME}" \
 --source-uri="${raw_stemcell_uri}" \
 ${guest_os_features_flag} \
 --storage-location=eu


gcloud compute images add-iam-policy-binding ${image_name} \
    --member='allAuthenticatedUsers' \
    --role='roles/compute.imageUser'

mkdir "${REPO_PARENT}/working_dir"
pushd "${REPO_PARENT}/working_dir"
# create final light stemcell
  tar xvf "${original_stemcell}"

  > image
  packaged_image_stemcell_sha1=$(sha1sum image | awk '{print $1}')

  cp stemcell.MF /tmp/stemcell.MF.tmp

  bosh int \
    -o "${REPO_ROOT}/ci/tasks/light-google/assets/public-image-stemcell-ops.yml" \
    -v "packaged_image_stemcell_sha1=$packaged_image_stemcell_sha1" \
    -v 'stemcell_formats=["google-light"]' \
    -v "image_url=https://www.googleapis.com/compute/v1/projects/${PROJECT_NAME}/global/images/${image_name}" \
    /tmp/stemcell.MF.tmp > stemcell.MF

  tar czvf "${REPO_PARENT}/light-stemcell/${light_stemcell_name}" *
popd
