#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:xenial-stemcells -c ci/xenial/pipeline.yml \
  -l <(lpass show --note "concourse:production pipeline:bosh:xenial-stemcells") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
