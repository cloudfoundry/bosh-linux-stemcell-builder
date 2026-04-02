#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

: ${ami_older_than_days:?}
: ${ami_keep_latest:?}

export AWS_ACCESS_KEY_ID=${ami_access_key}
export AWS_SECRET_ACCESS_KEY=${ami_secret_key}
export AWS_DEFAULT_REGION=${ami_region}

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

__PASTDUE=$(date --date="$ami_older_than_days days ago" +"%Y-%m-%d")

ami_destinations="$(aws ec2 describe-regions --output text --query "Regions[?RegionName][].RegionName")"

for region in $ami_destinations; do
    ami_list="[]"

    if [ "${remove_public_images:-}" == "true" ]; then
      results=$(aws ec2 describe-images \
              --owners self \
              --output json \
              --region ${region} \
              --filters "Name=name,Values=BOSH*" "Name=is-public,Values=true" \
              --query 'sort_by(Images,&CreationDate)[?CreationDate<`'"$__PASTDUE"'`].{ImageId: ImageId, date:CreationDate, SnapshotId: BlockDeviceMappings[0].Ebs.SnapshotId,Version: Tags[?Key==`name`]|[0].Value}')
      ami_list=$(jq -s '.[0] + .[1]' <(echo "${ami_list}") <(echo "${results}"))
    fi

    if [ -n "${os_name:-}" ]; then
      # 'ami_ids' array should be orderered by creation date
      results=$(aws ec2 describe-images \
              --owners self \
              --output json \
              --region ${region} \
              --filters "Name=name,Values=BOSH*" "Name=tag:published,Values=false" "Name=tag:distro,Values=${os_name}" \
              --query 'sort_by(Images,&CreationDate)[?CreationDate<`'"$__PASTDUE"'`].{ImageId: ImageId, date:CreationDate, SnapshotId: BlockDeviceMappings[0].Ebs.SnapshotId,Version: Tags[?Key==`name`]|[0].Value}' | jq 'reverse | del(.[range(env.ami_keep_latest|tonumber)])')
      ami_list=$(jq -s '.[0] + .[1]' <(echo "${ami_list}") <(echo "${results}"))
    fi

    if [ -n "${snapshot_id:-}" ]; then
      results=$(aws ec2 describe-images \
              --owners self \
              --output json \
              --region ${region} \
              --filters "Name=block-device-mapping.snapshot-id,Values=${snapshot_id}" \
              --query 'sort_by(Images,&CreationDate)[?CreationDate<`'"$__PASTDUE"'`].{ImageId: ImageId, date:CreationDate, SnapshotId: BlockDeviceMappings[0].Ebs.SnapshotId,Version: Tags[?Key==`name`]|[0].Value}' | jq 'reverse | del(.[range(env.ami_keep_latest|tonumber)])')
      ami_list=$(jq -s '.[0] + .[1]' <(echo "${ami_list}") <(echo "${results}"))
    fi

    # 'ami_list' is a json array of objects, each object is an ami and its snapshot
    for row in $(echo "${ami_list}" | jq -r '.[] | @base64'); do
      _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
      echo "
      ===============================================
      Cleaning up Ami and its snashots in $region
      Ami id:        $(_jq '.ImageId')
      Version:       $(_jq '.Version')
      Creation data: $(_jq '.date')
      Snapshot id:   $(_jq '.SnapshotId')
      "

      aws ec2 deregister-image \
        --image-id $(_jq '.ImageId') \
        --region $region

      if [ "${snapshot_id:-}" != "$(_jq '.SnapshotId')" ]; then
        aws ec2 delete-snapshot \
          --snapshot-id $(_jq '.SnapshotId') \
          --region $region
      fi
    done
done
