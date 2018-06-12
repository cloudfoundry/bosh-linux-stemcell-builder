#!/usr/bin/env bash

set -eu

absolute_path() {
  (cd "$1" && pwd)
}

scripts_path=$(absolute_path "$(dirname "$0")")

pipeline="bosh:stemcells"
args=""

if [ -n "${RELEASE_BRANCH:-}" ]; then
  pipeline="${pipeline}:${RELEASE_BRANCH}"
  args=(
    "-o ${scripts_path}/release-branch-pipeline-ops.yml"
    "-v release_branch=${RELEASE_BRANCH}"
    "-v initial_version=${RELEASE_BRANCH/.x/.1.0}"
  )
fi

fly -t production set-pipeline \
  -p "${pipeline}" \
  -c <(bosh interpolate ${args[*]} "${scripts_path}/pipeline.yml") \
  -l <(lpass show --notes "concourse:production pipeline:bosh:stemcells") \
  -l <(lpass show --notes "concourse:production pipeline:os-images") \
  -l <(lpass show --notes "bats-concourse-pool:vsphere secrets") \
  -l <(lpass show --notes "tracker-bot-story-delivery") \
  -l <(lpass show --notes "stemcell-reminder-bot")
