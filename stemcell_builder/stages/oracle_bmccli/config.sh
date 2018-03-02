#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
rm -rf ${dir}/bosh-bmccli
mkdir ${dir}/bosh-bmccli

curl -L -o ${dir}/bosh-bmccli/bosh-bmccli https://s3.amazonaws.com/bosh-bmccli/bosh-bmccli
echo "c4c528ee38f42f8f671417ebdafc32dc9816d2f8 ${dir}/bosh-bmccli/bosh-bmccli" | sha1sum -c -
