#!/bin/bash -exu

commit_bbl_state_dir() {
  local input_dir=${1?'Input git repository absolute path is required.'}
  local bbl_state_dir=${2?'BBL state relative path is required.'}
  local output_dir=${3?'Output git repository absolute path is required.'}
  local commit_message=${4:-'Update bbl state.'}

  pushd "${input_dir}/${bbl_state_dir}"
    if [[ -n $(git status --porcelain) ]]; then
      git config user.name "CI Bot"
      git config user.email "ci@localhost"
      git add --all .
      git commit -m "${commit_message}"
    fi
  popd

  shopt -s dotglob
  cp -R "${input_dir}/." "${output_dir}"
}

main() {
  local build_dir="${PWD}"
  local bbl_state_env_repo_dir=$PWD/bbl-state
  local output_dir="$PWD/updated-bbl-state/"
  local env_assets="$PWD/bosh-src/ci/acceptance"
  BBL_STATE_DIR=bosh-stemcell-acceptance-env
  export BBL_STATE_DIR

  trap "commit_bbl_state_dir ${bbl_state_env_repo_dir} ${BBL_STATE_DIR} ${output_dir} 'Update bosh-stemcell-acceptance-env environment'" EXIT

  mkdir -p "bbl-state/${BBL_STATE_DIR}"

  pushd "bbl-state/${BBL_STATE_DIR}"
    bbl version
    bbl plan > bbl_plan.txt

    # Customize environment
    cp $env_assets/*.sh .

    rm -rf bosh-deployment
    ln -s ${build_dir}/bosh-deployment bosh-deployment

    bbl --debug up

    set +x
    eval "$(bbl print-env)"
    set -x
    bosh upload-stemcell ${build_dir}/stemcell/*.tgz -n
    bosh -d zookeeper deploy --recreate ${build_dir}/zookeeper-release/manifests/zookeeper.yml -n -o \
			<(echo '{
					"type": "replace",
					"path": "/stemcells/alias=default/os",
					"value": "ubuntu-xenial"
				}'
			)
  popd
}

main "$@"
