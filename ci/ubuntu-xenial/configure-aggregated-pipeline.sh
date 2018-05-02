#!/usr/bin/env bash

set -eu

dir=$(dirname $0)

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]]; then
  echo -e "Do not run this script from any branch other than \033[1mmaster\033[0m"
  exit 1
fi

git fetch --all
git branch --track ubuntu-xenial/1.x origin/ubuntu-xenial/1.x 2>/dev/null || true

fly -t production set-pipeline \
  -p "bosh:stemcells:ubuntu-xenial" \
  -c <(
    bosh interpolate \
      -o <( bosh int -v group=master -v branch=master            -v initial_version=0.0.0  -v bump_version=major $dir/pipeline-branch-ops.yml ) \
      -o <( bosh int -v group=1.x    -v branch=ubuntu-xenial/1.x -v initial_version=1.98.0 -v bump_version=minor <( git show ubuntu-xenial/1.x:ci/ubuntu-xenial/pipeline-branch-ops.yml ) ) \
      $dir/pipeline-base.yml
  ) \
  -l <( lpass show --note "concourse:production pipeline:os-images" ) \
  -l <( lpass show --note "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --note "bats-concourse-pool:vsphere secrets" ) \
  -l <( lpass show --note "tracker-bot-story-delivery" )
