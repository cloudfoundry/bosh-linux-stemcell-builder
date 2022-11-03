#!/usr/bin/env bash
set -e
base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_config.bash"

# shellcheck disable=SC2154
downloaded_dir="${assets_dir}/downloaded"
persist_value downloaded_dir

rm -rf "${downloaded_dir}"
mkdir -p "${downloaded_dir}"

# shellcheck disable=SC2154
cli_url=$(cat "${assets_dir}/open-vm-tools.url")
cli_sha256sum=$(cat "${assets_dir}/open-vm-tools.sha256sum")

curl_five_times "${downloaded_dir}/open-vm-tools.tar.gz" "${cli_url}"
echo "${cli_sha256sum} ${downloaded_dir}/open-vm-tools.tar.gz" | sha256sum -c -