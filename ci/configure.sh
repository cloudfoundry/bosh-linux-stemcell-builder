#!/usr/bin/env bash
set -eu -o pipefail

STEMCELL_LINE="ubuntu-jammy"

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

fly="${FLY_CLI:-fly}"
concourse_target="${CONCOURSE_TARGET:-stemcell}"

until "${fly}" -t "${concourse_target}" status; do
  "${fly}" -t "${concourse_target}" login
  sleep 1
done

pipelines_dir="${REPO_ROOT}/ci/pipelines"
vars_file_name="vars.yml"

mapfile -t available_pipelines < \
  <( find "${pipelines_dir}" -maxdepth 1 -type f -name '*.yml' | grep -v "${vars_file_name}" | sort )

if (( ${#available_pipelines[@]} == 0 )); then
  echo "No pipelines found under '${pipelines_dir}'" >&2
  exit 1
fi

i=1
echo "Choose a pipeline to configure:"
for pipeline in "${available_pipelines[@]}"; do
  pipeline_choice_label=$(echo "${pipeline#"${pipelines_dir}/"}" | cut -d/ -f 1)
  printf "%4s. %s\n" "${i}" "${pipeline_choice_label}"
  i=$((i + 1))
done
read -rp "pipeline: " pipeline_index
echo ""

if ! [[ "${pipeline_index}" =~ ^[0-9]+$ ]] || (( pipeline_index < 1 || pipeline_index > ${#available_pipelines[@]} )); then
  echo "Invalid selection: '${pipeline_index}'" >&2
  exit 1
fi

pipeline_file=${available_pipelines[(pipeline_index-1)]}
if [ ! -f "${pipeline_file}" ]; then
  echo "No pipeline found: '${pipeline_file}'" >&2
  exit 1
fi

pipeline_name=$(basename "${pipeline_file%".yml"}")

echo "Configuring '${pipeline_name}' using '${pipeline_file#"${pipelines_dir}/"}'..."
echo ""

rendered_template="$(ytt -f "${pipeline_file}" -f "${pipelines_dir}/${vars_file_name}")"

"${fly}" -t "${concourse_target}" set-pipeline \
  -p "${STEMCELL_LINE}-${pipeline_name}" \
  -c <(echo "${rendered_template}")
