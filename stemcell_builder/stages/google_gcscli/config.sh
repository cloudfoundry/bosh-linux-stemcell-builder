#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf gcscli
mkdir gcscli
current_version=0.0.18

curl -L -o gcscli/gcscli https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-${current_version}-linux-amd64
echo "cfd7d76bdaea3027ea5687b971c2cbfeca7d4dd5 gcscli/gcscli" | sha1sum -c -
