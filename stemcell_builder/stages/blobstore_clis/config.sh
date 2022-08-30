#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_apply.bash"

# DAV CLI
dav_cli_binary=bosh-blobstore-dav
dav_cli_version=$(cat "${assets_dir}/${dav_cli_binary}.version")
dav_cli_sha256sum=$(cat "${assets_dir}/${dav_cli_binary}.sha256sum")
dav_cli_url=https://s3.amazonaws.com/davcli/davcli-${dav_cli_version}-linux-amd64

rm -rf "${assets_dir:?}/${dav_cli_binary}"
curl_five_times "${assets_dir}/${dav_cli_binary}" "${dav_cli_url}"
echo "${dav_cli_sha256sum} ${assets_dir}/${dav_cli_binary}" | sha256sum -c -


# GCS CLI
gcs_cli_binary=bosh-blobstore-gcs
gcs_cli_version=$(cat "${assets_dir}/${gcs_cli_binary}.version")
gcs_cli_sha256sum=$(cat "${assets_dir}/${gcs_cli_binary}.sha256sum")
gcs_cli_url=https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-${gcs_cli_version}-linux-amd64

rm -rf "${assets_dir:?}/${gcs_cli_binary}"
curl_five_times "${assets_dir}/${gcs_cli_binary}" "${gcs_cli_url}"
echo "${gcs_cli_sha256sum} ${assets_dir}/${gcs_cli_binary}" | sha256sum -c -


# S3 CLI
s3_cli_binary=bosh-blobstore-s3
s3_cli_version=$(cat "${assets_dir}/${s3_cli_binary}.version")
s3_cli_sha256sum=$(cat "${assets_dir}/${s3_cli_binary}.sha256sum")
s3_cli_url=https://s3.amazonaws.com/s3cli-artifacts/s3cli-${s3_cli_version}-linux-amd64

rm -rf "${assets_dir:?}/${s3_cli_binary}"
curl_five_times "${assets_dir}/${s3_cli_binary}" "${s3_cli_url}"
echo "${s3_cli_sha256sum} ${assets_dir}/${s3_cli_binary}" | sha256sum -c -
