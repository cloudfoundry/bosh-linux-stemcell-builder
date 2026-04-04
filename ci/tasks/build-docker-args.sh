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
apt-get install -y --no-install-recommends ca-certificates curl jq yq

meta4_cli_url="$(curl -s https://api.github.com/repos/dpb587/metalink/releases/latest \
                | jq -r '.assets[] | select(.name | match("meta4-[0-9]+.[0-9]+.[0-9]+-linux-amd64")) | .browser_download_url')"
syft_cli_url="$(curl -s https://api.github.com/repos/anchore/syft/releases/latest \
                | jq -r '.assets[] | select(.name | endswith ("_linux_amd64.tar.gz")) | .browser_download_url')"
yq_cli_url="$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest \
                | jq -r '.assets[] | select(.name | endswith ("linux_amd64")) | .browser_download_url')"

ruby_install_url="$(curl -s https://api.github.com/repos/postmodern/ruby-install/releases/latest \
                    | jq -r '.assets[] | select(.name | endswith ("tar.gz")) | .browser_download_url')"

ruby_version="$(cat "${REPO_ROOT}/.ruby-version")"
gem_home="/usr/local/bundle"

cat << EOF > "${REPO_PARENT}/docker-build-args/docker-build-args.json"
{
  "META4_CLI_URL": "${meta4_cli_url}",
  "SYFT_CLI_URL": "${syft_cli_url}",
  "YQ_CLI_URL": "${yq_cli_url}",

  "RUBY_INSTALL_URL": "${ruby_install_url}",
  "RUBY_VERSION": "${ruby_version}",
  "GEM_HOME": "${gem_home}",

  "placeholder": "without trailing comma"
}
EOF

cat "${REPO_PARENT}/docker-build-args/docker-build-args.json"
