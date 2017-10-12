#!/usr/bin/env bash

set -eu

STEMCELL_VERSION=3445.x

fly -t production set-pipeline -p bosh:os-image:$STEMCELL_VERSION \
    -c ci/os-images/pipeline.yml \
    --load-vars-from <(lpass show "concourse:production pipeline:os-images" --notes)
