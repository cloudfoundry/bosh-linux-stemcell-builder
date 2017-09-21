#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:os-image:3421.x \
    -c ci/os-images/pipeline.yml \
    --load-vars-from <(lpass show -G "concourse:production pipeline:os-images:branch:3421.x" --notes)
