#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

echo -n $stemcell_infrastructure > $chroot/var/vcap/bosh/etc/infrastructure

os="${stemcell_operating_system}"

echo -n ${os} > $chroot/var/vcap/bosh/etc/operating_system
echo -n ${stemcell_version} > $chroot/var/vcap/bosh/etc/stemcell_version

has_uncommitted_changes=""
git config --global --add safe.directory $PWD # fixes "fatal: unsafe repository"
if ! git diff --quiet --exit-code; then
  has_uncommitted_changes="+"
fi

echo -n $(git rev-parse HEAD)${has_uncommitted_changes} > $chroot/var/vcap/bosh/etc/stemcell_git_sha1
