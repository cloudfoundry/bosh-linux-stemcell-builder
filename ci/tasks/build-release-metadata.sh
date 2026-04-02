#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

version=$(cat "${REPO_PARENT}/stemcell-metalink/.resource/version" | sed 's/\.0$//')

mkdir -p "${REPO_PARENT}/release-metadata"
echo -n "${OS_NAME} ${OS_VERSION} v$version" > "${REPO_PARENT}/release-metadata/name"
echo -n "${OS_NAME}-${OS_VERSION}/v$version" > "${REPO_PARENT}/release-metadata/tag"

install_jq() {
  pushd $(mktemp -d)
    wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    echo "c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d  jq-linux64" > jq.txt
    shasum -c jq.txt
    chmod +x jq-linux64
    mv jq-linux64 /usr/bin/jq
  popd
}

install_jq

pushd "${REPO_PARENT}/candidate-stemcell"
  tar xvf bosh-stemcell-*-warden-boshlite-${OS_NAME}-${OS_VERSION}*.tgz packages.txt
  kernel_version=$(grep "${KERNEL_PACKAGE}" packages.txt | awk '{print $3}')
popd

pushd "${REPO_PARENT}/bosh-linux-stemcell-builder"
  bosh_agent_version=$(cat stemcell_builder/stages/bosh_go_agent/assets/bosh-agent-version)
  echo "## Metadata:" >> "${REPO_PARENT}/release-metadata/body"
  echo "**BOSH Agent Version**: ${bosh_agent_version}" >> "${REPO_PARENT}/release-metadata/body"
  echo "**Kernel Version**: ${kernel_version}" >> "${REPO_PARENT}/release-metadata/body"
  if [[ "${OS_NAME}" == "ubuntu" ]]; then
    # Ensure URL for usn-log from metalink exists before attempting to download.
    touch usn-log.json
    usn_metalink_path="bosh-stemcell/image-metalinks/${BRANCH}/${OS_NAME}-${OS_VERSION}.meta4"
    if [[ -n "$(meta4 file-urls --metalink "${usn_metalink_path}" --file usn-log.json)" ]]; then
      meta4 file-download --metalink "${usn_metalink_path}" --file usn-log.json usn-log.json --skip-hash-verification --skip-signature-verification
    fi

    echo "" >> "${REPO_PARENT}/release-metadata/body"
    echo "## USNs:" >> "${REPO_PARENT}/release-metadata/body"
    echo "$(${REPO_ROOT}/bin/format-usn-log usn-log.json)" >> "${REPO_PARENT}/release-metadata/body"
  fi
popd

echo "" > "${REPO_PARENT}/usn-log/usn-log.json"
