#!/usr/bin/env bash

set -eu

absolute_path() {
  (cd "$1" && pwd)
}

scripts_path=$(absolute_path "$(dirname "$0")")

STEMCELL_VERSION=3421.x

fly -t production set-pipeline \
  -p bosh:stemcells:$STEMCELL_VERSION -c "${scripts_path}/pipeline.yml" \
  -l <(lpass show --notes "concourse:production pipeline:bosh:stemcells:$STEMCELL_VERSION") \
  -l <(lpass show -G --notes "concourse:production pipeline:os-images:$STEMCELL_VERSION") \
  -l <(lpass show --notes "bats-concourse-pool:vsphere secrets") \
  -l <(lpass show --notes "tracker-bot-story-delivery") \
  -l <(lpass show --notes "stemcell-reminder-bot")
