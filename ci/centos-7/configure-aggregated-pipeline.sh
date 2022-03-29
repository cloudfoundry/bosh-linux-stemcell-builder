#!/usr/bin/env bash

set -euo pipefail

dir=$(dirname $0)

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]]; then
  echo -e "Do not run this script from any branch other than \033[1mmaster\033[0m"
  exit 1
fi

git fetch --all
git branch --track centos-7/3763.x origin/centos-7/3763.x 2>/dev/null || true

fly -t production set-pipeline \
  -p "bosh:stemcells:centos-7" \
  -c <(
    bosh interpolate \
      -o <( bosh int -v group=master -v branch=master -v initial_version="3728.0.0" -v bump_version=major $dir/pipeline-base-ops.yml ) \
      -o <( bosh int -v group=3763.x -v branch=centos-7/3763.x -v initial_version="3763.0.0" -v bump_version=minor <( git show centos-7/3763.x:ci/centos-7/pipeline-base-ops.yml ; git show centos-7/3763.x:ci/centos-7/pipeline-branch-ops.yml ) ) \
      $dir/pipeline-base.yml
  ) \
  -l <( lpass show --notes "concourse:production pipeline:os-images" ) \
  -l <( lpass show --notes "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --notes "bats-concourse-pool:vsphere secrets" ) \
  -l <(lpass show --notes "stemcell-reminder-bot")
