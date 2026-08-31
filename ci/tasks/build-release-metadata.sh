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

body_file="${REPO_PARENT}/release-metadata/body"
usn_log_json_file="${REPO_PARENT}/bosh-linux-stemcell-builder/usn-log.json"

format_usn_log() {
  local usn_data=${1}
  local include_description=${2}

  jq -r --slurp --argjson desc "${include_description}" < "${usn_data}" '.[] |
  "
  **Title**: " + .title +"
  **URL**: " + .url +"
  **Priorities**: " + (.priorities | join(",")) +
  (if $desc then "
  **Description**:
    " + .description else "" end) +"
  **CVEs**:
  " + (.cves | map(" - " + .) | join("\n"))
  '
}

write_body() {
  local include_description=${1}

  {
    echo "## Metadata:"
    echo "**BOSH Agent Version**: ${bosh_agent_version}"
    echo "**Kernel Version**: ${kernel_version}"

    if [[ "${OS_NAME}" == "ubuntu" ]]; then
      echo ""
      echo "## USNs:"
      if [[ "${include_description}" != "true" ]]; then
        echo "_USN descriptions omitted, see the USN URLs below for details._"
      fi
      format_usn_log "${usn_log_json_file}" "${include_description}"
    fi
  } > "${body_file}"
}

pushd "${REPO_PARENT}/candidate-stemcell"
  tar xvf bosh-stemcell-*-warden-boshlite-"${OS_NAME}"-"${OS_VERSION}"*.tgz packages.txt
  kernel_version=$(grep "${KERNEL_PACKAGE}" packages.txt | awk '{print $3}')
popd

bosh_agent_version=$(cat "${REPO_PARENT}/bosh-linux-stemcell-builder/stemcell_builder/stages/bosh_go_agent/assets/bosh-agent-version")

if [[ "${OS_NAME}" == "ubuntu" ]]; then
  # Ensure URL for usn-log from metalink exists before attempting to download.
  touch "${usn_log_json_file}"
  usn_metalink_path="${REPO_PARENT}/bosh-linux-stemcell-builder/image-metalinks/${BRANCH}/${OS_NAME}-${OS_VERSION}.meta4"
  if [[ -n "$(meta4 file-urls --metalink "${usn_metalink_path}" --file usn-log.json)" ]]; then
    meta4 file-download \
      --skip-hash-verification \
      --skip-signature-verification \
      --metalink "${usn_metalink_path}" \
      --file usn-log.json \
      "${usn_log_json_file}"
  fi
fi

write_body true

# GitHub rejects release bodies over 125,000 characters. wc -c counts bytes, which
# is >= the character count for UTF-8, so this guard fires early, never late.
MAX_BODY_LEN=120000
if [[ $(wc -c < "${body_file}") -gt ${MAX_BODY_LEN} ]]; then
  write_body false
fi

echo "" > "${REPO_PARENT}/usn-log/usn-log.json"
