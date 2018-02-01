#!/usr/bin/env bash

set -eu

args=""

# uncomment the following on release branches
#args="-o ci/release-branch-pipeline-ops.yml"

fly -t production set-pipeline \
  -p bosh:stemcells -c <( bosh interpolate $args ci/pipeline.yml ) \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
