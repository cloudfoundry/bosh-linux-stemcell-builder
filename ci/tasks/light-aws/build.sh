#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

ami_kms_key_id=${ami_kms_key_id:-}
ami_server_side_encryption=${ami_server_side_encryption:-}
ami_excluded_destinations=${ami_excluded_destinations:-}

: ${bosh_io_bucket_name:?}
: ${ami_description:?}
: ${ami_virtualization_type:?}
: ${ami_visibility:?}
: ${ami_region:?}
: ${ami_access_key:?}
: ${ami_secret_key:?}
: ${ami_bucket_name:?}
: ${ami_encrypted:?}
: ${efi:?}

export AWS_ACCESS_KEY_ID=$ami_access_key
export AWS_SECRET_ACCESS_KEY=$ami_secret_key
export AWS_DEFAULT_REGION=$ami_region

saved_ami_destinations="$( aws ec2 describe-regions \
  --query "Regions[?RegionName != '${ami_region}'][].RegionName" \
  | jq 'sort' -c )"

if [[ -n "${ami_excluded_destinations}" ]]; then
  saved_ami_destinations="$( echo "$saved_ami_destinations" \
    | jq --argjson exclude "$ami_excluded_destinations" '. - $exclude' -c )"
fi

: ${ami_destinations:=$saved_ami_destinations}

stemcell_path=$(ls "${REPO_PARENT}"/input-stemcell/*.tgz)
version=$(cat "${REPO_PARENT}/input-stemcell/.resource/version")

echo "Checking if light stemcell already exists..."

original_stemcell_name="$(basename "${stemcell_path}")"
light_stemcell_name="light-${original_stemcell_name}"

if [ "${ami_virtualization_type}" = "hvm" ]; then
  if [[ "${light_stemcell_name}" != *"-hvm"*  ]]; then
    light_stemcell_name="${light_stemcell_name/xen/xen-hvm}"
  fi
fi

bosh_io_light_stemcell_url="https://$S3_API_ENDPOINT/$bosh_io_bucket_name/$version/$light_stemcell_name"
set +e
wget --spider "$bosh_io_light_stemcell_url"
if [[ "$?" == "0" ]]; then
  echo "AWS light stemcell '$light_stemcell_name' already exists!"
  echo "You can download here: $bosh_io_light_stemcell_url"
  exit 1
fi
set -e

echo "Building light stemcell..."
echo "  Starting region: ${ami_region}"
echo "  Copy regions: ${ami_destinations}"

export CONFIG_PATH="${REPO_PARENT}/config.json"

cat > $CONFIG_PATH << EOF
{
  "ami_configuration": {
    "description":          "$ami_description",
    "virtualization_type":  "$ami_virtualization_type",
    "encrypted":            $ami_encrypted,
    "kms_key_id":           "$ami_kms_key_id",
    "visibility":           "$ami_visibility",
    "efi":                  ${efi}
  },
  "ami_regions": [
    {
      "name":               "$ami_region",
      "credentials": {
        "access_key":       "$ami_access_key",
        "secret_key":       "$ami_secret_key"
      },
      "bucket_name":        "$ami_bucket_name",
      "server_side_encryption": "$ami_server_side_encryption",
      "destinations":       $ami_destinations
    }
  ]
}
EOF

extracted_stemcell_dir="${REPO_PARENT}/extracted-stemcell"
mkdir -p ${extracted_stemcell_dir}
tar -C ${extracted_stemcell_dir} -xf ${stemcell_path}
tar -xf ${extracted_stemcell_dir}/image

# image format can be raw or stream optimized vmdk
stemcell_image="$(echo "${REPO_PARENT}"/root.*)"
stemcell_manifest=${extracted_stemcell_dir}/stemcell.MF
manifest_contents="$(cat ${stemcell_manifest})"

disk_regex="disk: ([0-9]+)"
format_regex="disk_format: ([a-z]+)"

[[ "${manifest_contents}" =~ ${disk_regex} ]]

mb_to_gb() { # rounds up to the nearest GB
  mb="$1"
  echo "$(( (mb+1024-1)/1024 ))"
}

disk_size_gb=$(mb_to_gb "${BASH_REMATCH[1]}")

[[ "${manifest_contents}" =~ ${format_regex} ]]
disk_format="${BASH_REMATCH[1]}"

pushd "${REPO_PARENT}/builder-src" > /dev/null
  # Make sure we've closed the manifest file before writing to it
  go run main.go \
    -c $CONFIG_PATH \
    --image ${stemcell_image} \
    --format ${disk_format} \
    --volume-size ${disk_size_gb} \
    --manifest ${stemcell_manifest} \
    | tee tmp-manifest

  mv tmp-manifest ${stemcell_manifest}

popd

pushd ${extracted_stemcell_dir}
  > image
  # the bosh cli sees the stemcell as invalid if tar contents have leading ./
  tar -czf "${REPO_PARENT}/light-stemcell/${light_stemcell_name}" *
popd

tar -tf "${REPO_PARENT}/light-stemcell/${light_stemcell_name}"
