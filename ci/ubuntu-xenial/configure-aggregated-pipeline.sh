#!/usr/bin/env bash

set -euo pipefail

dir=$(dirname $0)

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]]; then
  echo -e "Do not run this script from any branch other than \033[1mmaster\033[0m"
  exit 1
fi

git fetch --all

fly -t production set-pipeline \
  -p "bosh:stemcells:ubuntu-xenial" \
  -c <(
    bosh interpolate \
      -o <( bosh int -v group=master -v branch=master            -v initial_version=0.0.0  -v bump_version=major $dir/pipeline-branch-ops.yml ) \
      $dir/pipeline-base.yml
  ) \
  -l <( lpass show --notes "concourse:production pipeline:os-images" ) \
  -l <( lpass show --notes "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --notes "bats-concourse-pool:vsphere secrets" ) \
  -l <( lpass show --notes "tracker-bot-story-delivery" ) \
  -l <(lpass show --notes "stemcell-reminder-bot")
