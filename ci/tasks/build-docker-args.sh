#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

# When bumping, verify each new hash against the upstream release's checksums.
meta4_cli_url="https://github.com/dpb587/metalink/releases/download/v0.5.0/meta4-0.5.0-linux-amd64"
meta4_cli_sha256="9f3ff22e1ac3a8b4a667a9505dce2a224e099475ab69a02b23813ad073e27e01"

syft_cli_url="https://github.com/anchore/syft/releases/download/v1.52.0/syft_1.52.0_linux_amd64.tar.gz"
syft_cli_sha256="caeedb81fb0491615f1ebd1761e4145d41ee86dd2cc7bf80669f9f5ad9d6133d"

yq_cli_url="https://github.com/mikefarah/yq/releases/download/v4.54.1/yq_linux_amd64"
yq_cli_sha256="8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f"

ruby_install_url="https://github.com/postmodern/ruby-install/releases/download/v0.10.2/ruby-install-0.10.2.tar.gz"
ruby_install_sha256="65836158b8026992b2e96ed344f3d888112b2b105d0166ecb08ba3b4a0d91bf6"

ruby_version="$(cat "${REPO_ROOT}/.ruby-version")"
gem_home="/usr/local/bundle"

mkdir -p "${REPO_PARENT}/docker-build-args"
cat << EOF > "${REPO_PARENT}/docker-build-args/docker-build-args.yml"
META4_CLI_URL: "${meta4_cli_url}"
META4_CLI_SHA256: "${meta4_cli_sha256}"
SYFT_CLI_URL: "${syft_cli_url}"
SYFT_CLI_SHA256: "${syft_cli_sha256}"
YQ_CLI_URL: "${yq_cli_url}"
YQ_CLI_SHA256: "${yq_cli_sha256}"
RUBY_INSTALL_URL: "${ruby_install_url}"
RUBY_INSTALL_SHA256: "${ruby_install_sha256}"
RUBY_VERSION: "${ruby_version}"
GEM_HOME: "${gem_home}"
EOF

cat "${REPO_PARENT}/docker-build-args/docker-build-args.yml"
