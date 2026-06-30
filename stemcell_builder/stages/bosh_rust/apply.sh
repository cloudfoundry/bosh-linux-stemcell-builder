#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_apply.bash"
source "${base_dir}/lib/prelude_bosh.bash"

# rustup verifies downloaded toolchain integrity via its own signing chain; TLS on sh.rustup.rs is the trust anchor for the installer itself
curl_five_times "${chroot}/tmp/rustup-init.sh" "https://sh.rustup.rs"

run_in_chroot "${chroot}" "$(cat <<'SCRIPT'
  chmod +x /tmp/rustup-init.sh
  RUSTUP_HOME=/var/vcap/bosh/rustup \
  CARGO_HOME=/var/vcap/bosh/cargo \
  /tmp/rustup-init.sh -y --no-modify-path --default-toolchain stable
  rm /tmp/rustup-init.sh
  mkdir -p /var/vcap/bosh/bin
  ln -sf /var/vcap/bosh/cargo/bin/cargo /var/vcap/bosh/bin/cargo
  ln -sf /var/vcap/bosh/cargo/bin/rustc /var/vcap/bosh/bin/rustc
SCRIPT
)"
