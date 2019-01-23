#!/usr/bin/env bash

set -euo pipefail

dir=$(dirname $0)

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]]; then
  echo -e "Do not run this script from any branch other than \033[1mmaster\033[0m"
  exit 1
fi

git fetch --all
git branch --track ubuntu-xenial/97.x origin/ubuntu-xenial/97.x 2>/dev/null || true
git branch --track ubuntu-xenial/170.x origin/ubuntu-xenial/170.x 2>/dev/null || true

fly -t production set-pipeline \
  -p "bosh:stemcells:ubuntu-xenial" \
  -c <(
    bosh interpolate \
      -o <( bosh int -v group=master -v branch=master -v initial_version=0.0.0  -v bump_version=major -v bosh_agent_version='"*"' $dir/pipeline-base-ops.yml ) \
      -o <( bosh int $dir/pipeline-master-ops.yml ) \
      -o <( bosh int -v group=97.x -v branch=ubuntu-xenial/97.x -v initial_version=97.0.0 -v bump_version=minor <( git show ubuntu-xenial/97.x:ci/ubuntu-xenial/pipeline-base-ops.yml ) ) \
      -o <( bosh int -v group=97.x -v branch=ubuntu-xenial/97.x -v initial_version=97.0.0 -v bump_version=minor <( git show ubuntu-xenial/97.x:ci/ubuntu-xenial/pipeline-branch-ops.yml ) ) \
      -o <( bosh int -v group=170.x -v branch=ubuntu-xenial/170.x -v initial_version=170.0.0 -v bump_version=minor <( git show ubuntu-xenial/170.x:ci/ubuntu-xenial/pipeline-base-ops.yml ) ) \
      -o <( bosh int -v group=170.x -v branch=ubuntu-xenial/170.x -v initial_version=170.0.0 -v bump_version=minor <( git show ubuntu-xenial/170.x:ci/ubuntu-xenial/pipeline-branch-ops.yml ) ) \
      $dir/pipeline-base.yml
  ) \
  -l <( lpass show --notes "concourse:production pipeline:os-images" ) \
  -l <( lpass show --notes "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --notes "bats-concourse-pool:vsphere secrets" ) \
  -l <(lpass show --notes "stemcell-reminder-bot")
