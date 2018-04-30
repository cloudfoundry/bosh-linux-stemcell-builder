#!/usr/bin/env bash

set -eu

version="$( cat version/number )"
IFS="." read -r -a version_array <<< "$version"

echo "version is $version"

pushd "bosh-linux-stemcell-builder" > /dev/null
  git_branch=$( git branch --list --format="%(refname:short)" --contains HEAD | grep -v 'detached' )
  echo "branch is $git_branch"

  # for directory'd branches, only use the last, release.x part
  git_branch=$( basename "$git_branch" )
  echo "branch-version is $git_branch"
popd > /dev/null


if [[ "$git_branch" == "master" ]]; then
  echo "SKIPPED: version check is ignored on $git_branch"
  exit 0
fi

IFS="." read -r -a branch_array <<< "$git_branch"

if [[ "${branch_array[0]}" != "${version_array[0]}" ]]; then
  echo "ERROR: version does not match branch"
  exit 1
fi

echo "SUCCESS: version matches branch"
