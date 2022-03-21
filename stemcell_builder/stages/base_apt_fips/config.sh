#!/bin/bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

persist stemcell_operating_system_variant
persist UBUNTU_ADVANTAGE_TOKEN
