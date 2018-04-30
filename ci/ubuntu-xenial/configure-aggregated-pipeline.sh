#!/usr/bin/env bash

set -eu

dir=$(dirname $0)

fly -t production set-pipeline \
  -p "bosh:stemcells:ubuntu-xenial" \
  -c <(
    bosh interpolate \
      -o <( bosh int $dir/pipeline-branch-ops.yml -v group=master -v branch=master -v initial_version=0.0.0 ) \
      -o <( bosh int $dir/pipeline-branch-ops.yml -v group=1.x -v branch=xenial-1.x -v initial_version=1.98.0 ) \
      $dir/pipeline-base.yml
  ) \
  -l <( lpass show --note "concourse:production pipeline:os-images" ) \
  -l <( lpass show --note "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --note "bats-concourse-pool:vsphere secrets" ) \
  -l <( lpass show --note "tracker-bot-story-delivery" )

  #-o <( bosh int <( git show xenial-1.x:$dir/add_release_ops.yml ) -v group=1.x -v branch=xenial-1.x -v initial_version=1.98.0 ) \
