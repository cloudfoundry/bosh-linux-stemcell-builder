#!/usr/bin/env bash

set -e -x

# outputs
output_dir="version"
mkdir -p ${output_dir}

echo "${custom_stemcell_version}" > "${output_dir}/number"

