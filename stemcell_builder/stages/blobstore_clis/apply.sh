#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_apply.bash"
source "${base_dir}/lib/prelude_bosh.bash"

# shellcheck disable=SC2154
install --verbose \
  "${downloaded_cli_dir}"/bosh-blobstore-* \
  "${chroot}/var/vcap/bosh/bin/"
