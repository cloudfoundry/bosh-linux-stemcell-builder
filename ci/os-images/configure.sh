#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh:os-image \
    -c ci/os-images/pipeline.yml \
    --load-vars-from <(lpass show "concourse:production pipeline:os-images" --notes)
