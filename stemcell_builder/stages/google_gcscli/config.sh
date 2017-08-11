#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf gcscli
mkdir gcscli
current_version=0.0.3

curl -L -o gcscli/gcscli https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-${current_version}-linux-amd64
echo "a6ca3153856b40c1af6d79da8f11efdde0899b7d gcscli/gcscli" | sha1sum -c -
