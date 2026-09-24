#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

# install needed dependencies so that this task can be run on a stock ubuntu image
export DEBIAN_FRONTEND="noninteractive"
export LANG="en_US.UTF-8"
export LC_ALL="${LANG}"
export TZ="Etc/UTC"
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl jq

# Select CLI assets for the architecture this task runs on, so the builder image
# can be built for both amd64 and arm64 (Graviton) workers.
# RFC: https://github.com/cloudfoundry/community/pull/1530
case "$(uname -m)" in
  aarch64|arm64) arch="arm64" ;;
  *)             arch="amd64" ;;
esac

meta4_release="$(curl -s https://api.github.com/repos/dpb587/metalink/releases/latest)"
meta4_cli_url="$(jq -r --arg a "linux-${arch}" '.assets[] | select(.name | test("^meta4-[0-9]+\\.[0-9]+\\.[0-9]+-" + $a + "$")) | .browser_download_url' <<< "${meta4_release}")"
# dpb587/metalink publishes linux-amd64 only. When no prebuilt binary exists for
# this arch, META4_CLI_URL is left empty and the Dockerfile builds meta4 from
# source at META4_VERSION instead.
meta4_version="$(jq -r '.tag_name' <<< "${meta4_release}")"
syft_cli_url="$(curl -s https://api.github.com/repos/anchore/syft/releases/latest \
                | jq -r --arg a "_linux_${arch}.tar.gz" '.assets[] | select(.name | endswith ($a)) | .browser_download_url')"
yq_cli_url="$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest \
                | jq -r --arg a "linux_${arch}" '.assets[] | select(.name | endswith ($a)) | .browser_download_url')"

ruby_install_url="$(curl -s https://api.github.com/repos/postmodern/ruby-install/releases/latest \
                    | jq -r '.assets[] | select(.name | endswith ("tar.gz")) | .browser_download_url')"

ruby_version="$(cat "${REPO_ROOT}/.ruby-version")"
gem_home="/usr/local/bundle"

cat << EOF > "${REPO_PARENT}/docker-build-args/docker-build-args.yml"
META4_CLI_URL: "${meta4_cli_url}"
META4_VERSION: "${meta4_version}"
SYFT_CLI_URL: "${syft_cli_url}"
YQ_CLI_URL: "${yq_cli_url}"
RUBY_INSTALL_URL: "${ruby_install_url}"
RUBY_VERSION: "${ruby_version}"
GEM_HOME: "${gem_home}"
EOF

cat "${REPO_PARENT}/docker-build-args/docker-build-args.yml"
