#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf gcscli
mkdir gcscli
current_version=0.0.2

curl -L -o gcscli/gcscli https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-${current_version}-linux-amd64
echo "a151d3829f53b68bd15edfd3e6a527d187591992 gcscli/gcscli" | sha1sum -c -
