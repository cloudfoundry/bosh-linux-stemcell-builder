#!/bin/bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# do nothing if the needed env vars are not set or empty
if [ -z ${UBUNTU_ADVANTAGE_TOKEN+x} ]; then
    exit 0
fi

persist UBUNTU_ADVANTAGE_TOKEN
