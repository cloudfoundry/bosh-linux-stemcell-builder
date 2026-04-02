#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

if [ -n "${AWS_ROLE_ARN:-}" ]; then
  aws configure --profile creds_account set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
  aws configure --profile creds_account set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
  aws configure --profile resource_account set source_profile "creds_account"
  aws configure --profile resource_account set role_arn "${AWS_ROLE_ARN}"
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  export AWS_PROFILE=resource_account
fi

cd "${REPO_PARENT}/candidate-aws-light-stemcell"
tar -xzf *.tgz stemcell.MF
OS=$( cat stemcell.MF | grep operating_system | cut -f2 -d: | tr -d ' ')
#IGNORE gov and china stemcells. these are in a different account
AMI_LIST=$(cat stemcell.MF | grep ami- | tr -d ' '| eval $GREP_PATTERN)
VERSION=$(cat stemcell.MF | grep "^version" | cut -f2 -d: | tr -d ' ' | tr -d "'")
for AMI_LINE in $AMI_LIST; do
  AMI_REGION=$(echo $AMI_LINE | cut -f1 -d:)
  AMI_ID=$(echo $AMI_LINE | cut -f2 -d:)

  TAGS="[
    { \"Key\": \"published\", \"Value\": \"true\" },
    { \"Key\": \"name\"     , \"Value\": \"$OS-$VERSION\" },
    { \"Key\": \"distro\"   , \"Value\": \"$OS\" },
    { \"Key\": \"version\"  , \"Value\": \"$VERSION\" }
  ]"

  aws ec2 create-tags --resources "$AMI_ID" --region "$AMI_REGION" --tags "$TAGS"
done
