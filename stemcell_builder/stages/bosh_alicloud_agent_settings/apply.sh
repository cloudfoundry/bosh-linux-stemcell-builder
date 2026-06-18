#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# shellcheck disable=SC2154
cp "$assets_dir/agent.json" "$chroot/var/vcap/bosh/agent.json"
