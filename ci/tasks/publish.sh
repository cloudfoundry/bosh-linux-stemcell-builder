#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

export VERSION=$( cat "${REPO_PARENT}/version/number" | sed 's/\.0$//;s/\.0$//' )

#
# merge all stemcell files into a single metalink for publishing
#

git clone "${REPO_PARENT}/stemcells-index" "${REPO_PARENT}/stemcells-index-output"

meta4_path="${REPO_PARENT}/stemcells-index-output/$TO_INDEX/$OS_NAME-$OS_VERSION/$VERSION/stemcells.meta4"

mkdir -p "$( dirname "$meta4_path" )"
meta4 create --metalink="$meta4_path"

find "${REPO_PARENT}/stemcells-index-output/$FROM_INDEX/$OS_NAME-$OS_VERSION/$VERSION" -name "*.meta4" \
  | xargs -n1 -- meta4 import-metalink --metalink="$meta4_path"

cd "${REPO_PARENT}/stemcells-index-output"

git add -A
git config --global user.email "ci@localhost"
git config --global user.name "CI Bot"
git commit -m "$COMMIT_PREFIX: $OS_NAME-$OS_VERSION/$VERSION"

cd "${REPO_PARENT}"

#
# copy s3 objects into the public bucket
#
#TODO: use gcp or use aws and use google s3 url s3://storage.googleapis.com/$FROM_BUCKET_NAME

if [ -n "${AWS_ROLE_ARN}" ]; then
  aws configure --profile creds_account set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
  aws configure --profile creds_account set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
  aws configure --profile resource_account set source_profile "creds_account"
  aws configure --profile resource_account set role_arn "${AWS_ROLE_ARN}"
  aws configure --profile resource_account set region "${AWS_DEFAULT_REGION}"
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  export AWS_PROFILE=resource_account
fi

# Parse the JSON array into a Bash array
COPY_KEYS_ARRAY=($(echo "$COPY_KEYS" | jq -r '.[]'))

if [ ${#COPY_KEYS_ARRAY[@]} -eq 0 ]; then
    echo "COPY_KEYS is empty. No files to process."
    exit 1  # Exit or handle as needed
fi

if [ "$FROM_BUCKET_NAME" == "$TO_BUCKET_NAME" ]; then
  echo "Skipping upload since buckets are the same..."
elif [ ${#COPY_KEYS_ARRAY[@]} -eq 0 ]; then
  echo "Skipping upload since COPY_KEYS is empty..."
else
  for file in "${COPY_KEYS_ARRAY[@]}"; do
    file="${file/\%s/$VERSION}"

    echo "$file"

    # occasionally this fails for unexpected reasons; retry a few times
    for i in {1..4}; do
      aws --endpoint-url=${AWS_ENDPOINT} s3 cp "s3://$FROM_BUCKET_NAME/$file" "s3://$TO_BUCKET_NAME/$file" \
        && break \
        || sleep 5
    done

    echo ""
  done
fi

echo "${OS_NAME}-${OS_VERSION}/v${VERSION}" > "${REPO_PARENT}/version-tag/tag"

echo "Done"
