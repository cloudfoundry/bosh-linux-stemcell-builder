#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf "$(dirname "${0}")/../..")
source "${base_dir}/lib/prelude_apply.bash"
source "${base_dir}/lib/prelude_bosh.bash"

rust_version="1.96.1"

# rustup verifies downloaded toolchain integrity via its own signing chain; TLS on sh.rustup.rs is the trust anchor for the installer itself
rustup_installer=$(mktemp "${chroot}/tmp/rustup-init.XXXXXX")
curl_five_times "${rustup_installer}" "https://sh.rustup.rs"

run_in_chroot "${chroot}" "$(cat <<SCRIPT
  installer=\$(basename ${rustup_installer})
  chmod +x "/tmp/\${installer}"
  RUSTUP_HOME=/var/vcap/bosh/rustup \\
  CARGO_HOME=/var/vcap/bosh/cargo \\
  "/tmp/\${installer}" -y --no-modify-path --default-toolchain ${rust_version}
  rm "/tmp/\${installer}"
  mkdir -p /var/vcap/bosh/bin
  ln -sf /var/vcap/bosh/cargo/bin/cargo /var/vcap/bosh/bin/cargo
  ln -sf /var/vcap/bosh/cargo/bin/rustc /var/vcap/bosh/bin/rustc
SCRIPT
)"
