#!/usr/bin/env bash
set -eu -o pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

STEMCELL_LINE="ubuntu-jammy"

pipelines_dir="${REPO_ROOT}/ci"
pipeline_name="${STEMCELL_LINE}"
pipeline_template="pipeline-template.yml"
pipeline_vars="pipeline-vars.yml"

concourse_target="${CONCOURSE_TARGET:-stemcell}"
fly="${FLY_CLI:-fly}"

until "${fly}" -t "${concourse_target}" status; do
  "${fly}" -t "${concourse_target}" login
  sleep 1
done

echo "Rendering..."
rendered_template="$(ytt -f "${pipelines_dir}/${pipeline_template}" -f "${pipelines_dir}/${pipeline_vars}")"
echo ""

echo "Validating..."
"${fly}" validate-pipeline --strict --config <(echo "${rendered_template}")
echo ""

echo "Configuring..."
"${fly}" -t "${concourse_target}" set-pipeline -p "${pipeline_name}" \
  -c <(echo "${rendered_template}")
