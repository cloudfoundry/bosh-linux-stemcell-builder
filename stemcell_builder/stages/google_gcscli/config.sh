#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf gcscli
mkdir gcscli
current_version=0.0.16

curl -L -o gcscli/gcscli https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-${current_version}-linux-amd64
echo "94685c1a460203575df6c039cfdd841cc26fbec2 gcscli/gcscli" | sha1sum -c -
