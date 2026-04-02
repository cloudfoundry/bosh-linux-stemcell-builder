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
  pushd "$(mktemp -d)"
    wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    echo "c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d  jq-linux64" > jq.txt
    shasum -c jq.txt
    chmod +x jq-linux64
    mv jq-linux64 /usr/bin/jq
  popd
}

install_jq

pushd "${REPO_PARENT}/candidate-stemcell"
  tar xvf bosh-stemcell-*-warden-boshlite-"${OS_NAME}"-"${OS_VERSION}"*.tgz packages.txt
  kernel_version=$(grep "${KERNEL_PACKAGE}" packages.txt | awk '{print $3}')
popd

bosh_agent_version=$(cat "${REPO_PARENT}/bosh-linux-stemcell-builder/stemcell_builder/stages/bosh_go_agent/assets/bosh-agent-version")
{
  echo "## Metadata:"
  echo "**BOSH Agent Version**: ${bosh_agent_version}"
  echo "**Kernel Version**: ${kernel_version}"
} >> "${REPO_PARENT}/release-metadata/body"

if [[ "${OS_NAME}" == "ubuntu" ]]; then
  # Ensure URL for usn-log from metalink exists before attempting to download.
  usn_log_json_file="${REPO_PARENT}/bosh-linux-stemcell-builder/${usn_log_json_file}/usn-log.json"
  touch "${usn_log_json_file}"
  usn_metalink_path="${REPO_PARENT}/bosh-linux-stemcell-builder/bosh-stemcell/image-metalinks/${BRANCH}/${OS_NAME}-${OS_VERSION}.meta4"
  if [[ -n "$(meta4 file-urls --metalink "${usn_metalink_path}" --file "${usn_log_json_file}")" ]]; then
    meta4 file-download \
      --skip-hash-verification \
      --skip-signature-verification \
      --metalink "${usn_metalink_path}" \
      --file "${usn_log_json_file}" \
      "${usn_log_json_file}"
  fi

  {
    echo ""
    echo "## USNs:"
    "${REPO_ROOT}/ci/bin/format-usn-log" "${usn_log_json_file}"
  } >> "${REPO_PARENT}/release-metadata/body"
fi

echo "" > "${REPO_PARENT}/usn-log/usn-log.json"
