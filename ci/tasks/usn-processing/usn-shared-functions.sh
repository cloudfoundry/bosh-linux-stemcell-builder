#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

#
# This script goes through the list of ubuntu security notices (USNs) and makes sure that packages
# listed in every USN are available in apt repositories for installation.
# We do this to make sure that a newly released stemcell includes fixes for USNs that tirggered the build.
#

function process_packages {
  local package_version_for_usn=("$@")

  for package_version in "${package_version_for_usn[@]}"
  do
    # single package
    package=$(echo "$package_version" | cut -d ':' -f1)
    version=$(echo "$package_version" | cut -d ':' -f2)

    if is_package_installed "$package";
    then
      PACKAGE_INCLUDED_IN_STEMCELL=true
      echo "checking: $package"
      check_package "$package" "$version"
    else
      echo "skip: $package"
    fi
  done
}

function candidate_version_to_install {
  local package_name=$1
  local candidate
  candidate=$(sudo apt policy "$package_name" 2>/dev/null | grep Candidate | tr -s ' ' | cut -d ' ' -f3)
  echo "$candidate"
}

function check_package {
  local package=$1
  local version=$2
  local candidate_version

  candidate_version=$(candidate_version_to_install "$package")

  if ! dpkg --compare-versions "$candidate_version" ge "$version";
  then
    ALL_PACKAGE_VERSIONS_AVAILABLE=false
    echo -e "L \e[31mexpected version from USN: $version, available in repo: $candidate_version\e[0m"
  else
    echo -e "L repo version: $candidate_version matches USN version: $version"
  fi
}

function enable_esm {
  apt-get update
  apt-get install -y ca-certificates ubuntu-advantage-tools
  ua attach "${ESM_TOKEN}" --no-auto-enable
  ua enable esm-infra
}

function process_usns {
  local usn_log_json=$1
  local usn_gh_path=$2

  mapfile -t usn_urls < <(jq -r '.url | select(.|test("USN"))' "$usn_log_json" | sort | uniq)
  # Check the BASH docs for details, but wait will wait on the subshell above and exit w/ it exit code.
  wait $! || (echo "jq failed while searching for USNs. Has the feed format (or USN file that we generate) changed?" && exit 1)

  for usn_url in "${usn_urls[@]}"
  do
    # list of packages
    echo -e "\n>>>>> $usn_url <<<<<"
    usn_id=$( echo $usn_url | cut -d '/' -f6 | cut -d '-' -f2,3)

    mapfile -t package_version_for_usn < <( cat "${usn_gh_path}/${usn_id}.json" | jq --arg os $OS -r '.releases[$os].allbinaries | keys[] as $k | "\($k):\(.[$k].version)"')
    # Check the BASH docs for details, but wait will wait on the subshell above and exit w/ it exit code.
    wait $! || (echo "Either curl or jq failed while processing USN URL '$usn_url' for OS '$OS'" && exit 1)
    process_packages "${package_version_for_usn[@]}"
  done
}

function is_package_installed {
  local package=$1
  echo "$INSTALLED_PACKAGES" | grep -q "$package$"
  return $?
}

if [[ -n "$ESM_TOKEN" ]]; then
  enable_esm
fi

if [[ -z "${OS}" ]]; then
  echo "Environment variable 'OS' must be set, and not empty"
  exit 1
fi

# Depends on apt package list being up-to-date, make sure apt-get update is run before this is executed
sudo apt-get update
INSTALLED_PACKAGES=$(cat "${REPO_PARENT}"/bosh-linux-stemcell-builder/bosh-stemcell/spec/assets/dpkg-list-ubuntu*.txt | sort | uniq | sed -e 's/:amd64//g')
ALL_PACKAGE_VERSIONS_AVAILABLE=true
PACKAGE_INCLUDED_IN_STEMCELL=false
