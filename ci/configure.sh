#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:stemcells:3469.x -c ci/pipeline.yml \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
  -v stemcell_branch=3469.x \
  -v stemcell_version_key=bosh-stemcell/version-3469.x \
  -v stemcell_version_semver_bump=minor
