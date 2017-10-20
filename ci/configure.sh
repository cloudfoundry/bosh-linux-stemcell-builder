#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:stemcells:3468.x -c ci/pipeline.yml \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
  -v stemcell_branch=3468.x \
  -v stemcell_version_key=bosh-stemcell/version-3468.x \
  -v stemcell_version_semver_bump=minor
