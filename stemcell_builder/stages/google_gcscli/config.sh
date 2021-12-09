#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf gcscli
mkdir gcscli
current_version=0.0.21

curl -L -o gcscli/gcscli https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-${current_version}-linux-amd64
echo "37bb0210c9e182685da30d870e61bd88cd33831e202e42b508effb2b55c662e3 gcscli/gcscli" | sha256sum -c -
