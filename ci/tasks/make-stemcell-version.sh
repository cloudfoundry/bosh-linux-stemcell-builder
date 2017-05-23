#!/usr/bin/env bash

set -e -x

# outputs
output_dir="version"
mkdir -p ${output_dir}

[ -f published-stemcell/version ] || exit 1

published_version=$(cat published-stemcell/version)

# check for minor (only supports x and x.x)
if [[ "$published_version" == *.* ]]; then
	echo "${published_version}.0" > "${output_dir}/number" # fill in patch
else
	echo "${published_version}.0.0" > "${output_dir}/number" # fill in minor.patch
fi
