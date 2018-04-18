#!/usr/bin/env bash

set -eu

pipeline="bosh:stemcells"
args=""

if [ -n "${RELEASE_BRANCH:-}" ]; then
  pipeline="$pipeline:$RELEASE_BRANCH"
  release_prefix=$(echo "$RELEASE_BRANCH" | cut -d- -f1)
  release_version=$(echo "$RELEASE_BRANCH" | cut -d- -f2)
  if [ -n "${INITIAL_STEMCELL_VERSION:-}" ]; then
    initial_version=${INITIAL_STEMCELL_VERSION}
  else
    initial_version="$(echo "$release_version" | cut -d. -f1).0.0"
  fi
  args="
    -v release_branch=${RELEASE_BRANCH}
    -v initial_version=${initial_version}
    -v stemcell_os=${STEMCELL_OS}
    -v stemcell_os_version=${STEMCELL_OS_VERSION}
    -v stemcell_version_prefix=${release_prefix}
  "
fi

fly -t production set-pipeline \
  -p "$pipeline" \
  -c <( bosh interpolate $args ci/single-stemcell/pipeline.yml ) \
  -l <( lpass show --note "concourse:production pipeline:os-images" ) \
  -l <( lpass show --note "concourse:production pipeline:bosh:stemcells" ) \
  -l <( lpass show --note "bats-concourse-pool:vsphere secrets" ) \
  -l <( lpass show --note "tracker-bot-story-delivery" )
