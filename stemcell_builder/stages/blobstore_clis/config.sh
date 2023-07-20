#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_config.bash"

# shellcheck disable=SC2154
downloaded_cli_dir="${assets_dir}/downloaded_clis"
persist_value downloaded_cli_dir

rm -rf "${downloaded_cli_dir}"
mkdir -p "${downloaded_cli_dir}"

blobstore_clis=(bosh-blobstore-dav bosh-blobstore-gcs bosh-blobstore-s3 bosh-blobstore-az)

for cli_binary in "${blobstore_clis[@]}"; do
  # shellcheck disable=SC2154
  cli_url=$(cat "${assets_dir}/${cli_binary}.url")
  cli_sha256sum=$(cat "${assets_dir}/${cli_binary}.sha256sum")

  curl_five_times "${downloaded_cli_dir}/${cli_binary}" "${cli_url}"
  echo "${cli_sha256sum} ${downloaded_cli_dir}/${cli_binary}" | sha256sum -c -
done
