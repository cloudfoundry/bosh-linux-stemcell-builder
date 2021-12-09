#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf s3cli
mkdir s3cli
current_version=0.0.106
curl_five_times "s3cli/s3cli" "https://s3.amazonaws.com/s3cli-artifacts/s3cli-${current_version}-linux-amd64"
echo "e2df43d32d97d4b30c4d5fc2706c1d10eb36dccb3320ecf8df200874326edebd s3cli/s3cli" | sha256sum -c -
