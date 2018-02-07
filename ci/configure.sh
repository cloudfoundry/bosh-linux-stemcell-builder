#!/usr/bin/env bash

set -eu

pipeline="bosh:stemcells"
args=""

if [ -n "${RELEASE_BRANCH:-}" ]; then
  pipeline="$pipeline:$RELEASE_BRANCH"
  args="
    -o ci/release-branch-pipeline-ops.yml
    -v release_branch=$RELEASE_BRANCH
    -v initial_version=${RELEASE_BRANCH/.x/.0.0}
  "
fi

fly -t production set-pipeline \
  -p "$pipeline" -c <( bosh interpolate $args ci/pipeline.yml ) \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
