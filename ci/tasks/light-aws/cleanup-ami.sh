#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

: "${ami_older_than_days:?}"
: "${ami_keep_latest:?}"
: "${ami_access_key:?}"
: "${ami_secret_key:?}"
: "${ami_region:?}"

export AWS_ACCESS_KEY_ID="${ami_access_key}"
export AWS_SECRET_ACCESS_KEY="${ami_secret_key}"
export AWS_DEFAULT_REGION="${ami_region}"

if [ -n "${ami_role_arn:-}" ]; then
  export AWS_ROLE_ARN=${ami_role_arn}
  aws configure --profile creds_account set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
  aws configure --profile creds_account set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
  aws configure --profile resource_account set source_profile "creds_account"
  aws configure --profile resource_account set role_arn "${AWS_ROLE_ARN}"
  aws configure --profile resource_account set region "${AWS_DEFAULT_REGION}"
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  export AWS_PROFILE=resource_account
fi

# Every stemcell pipeline runs the published sweep against the same account, so two
# pipelines can select the same AMI before either has deleted it. This handles
# expected potential errors that could occur on a collision.
run_tolerating_missing() {
  local output
  if output="$("$@" 2>&1)"; then
    [ -n "${output}" ] && printf "%s\n" "${output}"
    return 0
  fi

  case "${output}" in
    *InvalidAMIID.Unavailable*|*InvalidAMIID.NotFound*|*InvalidSnapshot.NotFound*|*InvalidSnapshot.InUse*)
      echo "    already deleted by another run, skipping"
      return 0
      ;;
    *)
      printf "%s\n" "${output}" >&2
      return 1
      ;;
  esac
}

past_due=$(date --date="${ami_older_than_days} days ago" +"%Y-%m-%d")
# shellcheck disable=SC2016
past_due_query='sort_by(Images,&CreationDate)[?CreationDate<`'"${past_due}"'`].{ImageId: ImageId, date:CreationDate, SnapshotId: BlockDeviceMappings[0].Ebs.SnapshotId,Version: Tags[?Key==`name`]|[0].Value}'
ami_destinations="$(aws ec2 describe-regions --output text --query "Regions[?RegionName][].RegionName")"

for region in ${ami_destinations}; do
  ami_list="[]"

  if [ "${remove_public_images:-}" == "true" ]; then
    results=$(aws ec2 describe-images \
            --owners self \
            --output json \
            --region "${region}" \
            --filters "Name=name,Values=BOSH*" "Name=is-public,Values=true" \
            --query "${past_due_query}")
    ami_list=$(jq -s '.[0] + .[1]' <(echo "${ami_list}") <(echo "${results}"))
  fi

  if [ -n "${os_name:-}" ]; then
    # 'ami_ids' array should be ordered by creation date
    results=$(aws ec2 describe-images \
            --owners self \
            --output json \
            --region "${region}" \
            --filters "Name=name,Values=BOSH*" "Name=tag:published,Values=false" "Name=tag:distro,Values=${os_name}" \
            --query "${past_due_query}" | jq 'reverse | del(.[range(env.ami_keep_latest|tonumber)])')
    ami_list=$(jq -s '.[0] + .[1]' <(echo "${ami_list}") <(echo "${results}"))
  fi

  # 'ami_list' is a json array of objects, each object is an ami and its snapshot
  for row in $(echo "${ami_list}" | jq -r '.[] | @base64'); do
    _jq() {
      echo "${row}" | base64 --decode | jq -r "${1}"
    }
    echo "
    ===============================================
    Cleaning up Ami and its snashots in ${region}
    Ami id:        $(_jq '.ImageId')
    Version:       $(_jq '.Version')
    Creation data: $(_jq '.date')
    Snapshot id:   $(_jq '.SnapshotId')
    "

    run_tolerating_missing aws ec2 deregister-image \
      --image-id "$(_jq '.ImageId')" \
      --region "${region}"

    run_tolerating_missing aws ec2 delete-snapshot \
      --snapshot-id "$(_jq '.SnapshotId')" \
      --region "${region}"
  done
done
