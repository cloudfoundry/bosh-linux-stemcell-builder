#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:stemcells:3431.x -c ci/pipeline.yml \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells:3431.x") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
