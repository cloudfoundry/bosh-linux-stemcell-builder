#!/usr/bin/env bash

set -eu

pipeline="bosh:os-image"
args=""

if [ -n "${RELEASE_BRANCH:-}" ]; then
  pipeline="$pipeline:$RELEASE_BRANCH"
  args="-v branch=$RELEASE_BRANCH"
fi

fly -t production set-pipeline \
  -p "$pipeline" \
  -c ci/os-images/pipeline.yml \
  --load-vars-from <(lpass show "concourse:production pipeline:os-images" --notes) \
  $args
