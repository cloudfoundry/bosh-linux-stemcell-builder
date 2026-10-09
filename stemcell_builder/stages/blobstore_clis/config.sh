#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_config.bash"

# shellcheck disable=SC2154
downloaded_cli_dir="${assets_dir}/downloaded_clis"
persist_value downloaded_cli_dir

rm -rf "${downloaded_cli_dir}"
mkdir -p "${downloaded_cli_dir}"

blobstore_clis=(bosh-blobstore-dav bosh-blobstore-gcs bosh-blobstore-s3 bosh-blobstore-azure-storage)

# The <cli>.url/.sha256sum assets point at linux-amd64 builds. Other
# architectures (e.g. arm64 / Graviton) read <cli>.linux-<arch>.url/.sha256sum.
# RFC: cloudfoundry/community#1530
# shellcheck disable=SC2154
cli_arch="${stemcell_arch:-amd64}"
if [ "${cli_arch}" == "amd64" ]; then
  cli_asset_suffix=""
else
  cli_asset_suffix=".linux-${cli_arch}"
fi

for cli_binary in "${blobstore_clis[@]}"; do
  if [ ! -f "${assets_dir}/${cli_binary}${cli_asset_suffix}.url" ]; then
    echo "No linux-${cli_arch} build of ${cli_binary} is configured: expected ${cli_binary}${cli_asset_suffix}.url and .sha256sum in ${assets_dir}" >&2
    exit 1
  fi
  # shellcheck disable=SC2154
  cli_url=$(cat "${assets_dir}/${cli_binary}${cli_asset_suffix}.url")
  cli_sha256sum=$(cat "${assets_dir}/${cli_binary}${cli_asset_suffix}.sha256sum")

  curl_five_times "${downloaded_cli_dir}/${cli_binary}" "${cli_url}"
  echo "${cli_sha256sum} ${downloaded_cli_dir}/${cli_binary}" | sha256sum -c -
done
