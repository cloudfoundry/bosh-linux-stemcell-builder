#!/usr/bin/env bash

set -e

base_dir="$(readlink -nf "$(dirname "$0")"/../..)"
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

# shellcheck disable=SC2154
if [ "${stemcell_operating_system}" == "ubuntu" ] || \
   [ "${stemcell_operating_system_version}" == "7" ] || \
   [ "${stemcell_operating_system}" == "photonos" ] || \
   [ "${stemcell_operating_system}" ==  "opensuse" ]; then

  cp "$dir/assets/60-bosh-sysctl.conf" "$chroot/etc/sysctl.d"
  chmod 0644 "$chroot/etc/sysctl.d/60-bosh-sysctl.conf"

  cp "$dir/assets/60-bosh-sysctl-neigh-fix.conf" "$chroot/etc/sysctl.d"
  chmod 0644 "$chroot/etc/sysctl.d/60-bosh-sysctl-neigh-fix.conf"
fi
