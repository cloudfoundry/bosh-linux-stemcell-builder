#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

function check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

check_param IAAS
check_param HYPERVISOR
check_param OS_NAME
check_param OS_VERSION
AGENT_SUFFIX="${AGENT_SUFFIX--go_agent}"

export CANDIDATE_BUILD_NUMBER=$( cat "${REPO_PARENT}/version/number" | sed 's/\.0$//;s/\.0$//' )

git clone "${REPO_PARENT}/stemcells-index" "${REPO_PARENT}/stemcells-index-output"

# This is copied from https://github.com/concourse/concourse/blob/3c070db8231294e4fd51b5e5c95700c7c8519a27/jobs/baggageclaim/templates/baggageclaim_ctl.erb#L23-L54
# helps the /dev/mapper/control issue and lets us actually do scary things with the /dev mounts
# This allows us to create device maps from partition tables in image_create/apply.sh
function permit_device_control() {
  local devices_mount_info=$(cat /proc/self/cgroup | grep devices)

  if [ -z "$devices_mount_info" ]; then
    # cgroups v2: the devices controller is managed via eBPF and has no
    # filesystem interface. Privileged containers already have full device
    # access, so there is nothing to do here.
    return 0
  fi

  local devices_subsytems=$(echo $devices_mount_info | cut -d: -f2)
  local devices_subdir=$(echo $devices_mount_info | cut -d: -f3)

  cgroup_dir=/mnt/tmp-todo-devices-cgroup

  if [ ! -e ${cgroup_dir} ]; then
    # mount our container's devices subsystem somewhere
    mkdir ${cgroup_dir}
  fi

  if ! mountpoint -q ${cgroup_dir}; then
    mount -t cgroup -o $devices_subsytems none ${cgroup_dir}
  fi

  # permit our cgroup to do everything with all devices
  # ignore failure in case something has already done this; echo appears to
  # return EINVAL, possibly because devices this affects are already in use
  echo a > ${cgroup_dir}${devices_subdir}/devices.allow || true
}

permit_device_control

# Also copied from baggageclaim_ctl.erb creates 64 loopback mappings. This fixes failures with losetup --show --find ${disk_image}
for i in $(seq 0 64); do
  if ! mknod -m 0660 /dev/loop$i b 7 $i; then
    break
  fi
done

chown -R ubuntu:ubuntu "${REPO_PARENT}/bosh-linux-stemcell-builder"
chown -R ubuntu:ubuntu /mnt

OS_IMAGE=""
mkdir -p "${REPO_PARENT}/os-image-tarball"
if [[ -n "$(ls -A "${REPO_PARENT}/os-image-tarball/")" ]]; then
	OS_IMAGE="$(readlink -f "${REPO_PARENT}/os-image-tarball"/*.tgz)"
fi

sudo chmod u+s $(which sudo)
sudo --preserve-env --set-home --user ubuntu -- /bin/bash --login -i <<SUDO
  set -e

  cd "${REPO_PARENT}/bosh-linux-stemcell-builder"
case $OS_VERSION
in
# Because of the difference in build environments between Xenial and other Ubuntu stemcell lines (currently only Jammy)
# we must run 'bundle install' as the root user for it to function correctly.
"xenial")
    sudo bundle update --bundler
    sudo bundle install --local
    ;;
*)
    bundle update --bundler
    bundle install --local
    ;;
esac

if [[ -z "$OS_IMAGE" ]]; then
	bundle exec rake stemcell:build[$IAAS,$HYPERVISOR,$OS_NAME,$OS_VERSION,$CANDIDATE_BUILD_NUMBER]
	rm -f ./tmp/base_os_image.tgz
else
	bundle exec rake stemcell:build_with_local_os_image[$IAAS,$HYPERVISOR,$OS_NAME,$OS_VERSION,$OS_IMAGE,$CANDIDATE_BUILD_NUMBER]
fi
SUDO

#
# Output and checksum the stemcell artifacts
#

stemcell_name="bosh-stemcell-$CANDIDATE_BUILD_NUMBER-$IAAS-$HYPERVISOR-$OS_NAME-$OS_VERSION${AGENT_SUFFIX}"
meta4_path="${REPO_PARENT}/stemcells-index-output/dev/$OS_NAME-$OS_VERSION/$CANDIDATE_BUILD_NUMBER/$IAAS-$HYPERVISOR${AGENT_SUFFIX}.meta4"

echo $CANDIDATE_BUILD_NUMBER > "${REPO_PARENT}/candidate-build-number/number"
mkdir -p "$( dirname "$meta4_path" )"
rm -f "$meta4_path"
meta4 create --metalink="$meta4_path"

if [ -e "${REPO_PARENT}/bosh-linux-stemcell-builder/tmp"/*-raw.tgz ] ; then
  # openstack currently publishes raw files
  raw_stemcell_filename="${stemcell_name}-raw.tgz"
  mv "${REPO_PARENT}/bosh-linux-stemcell-builder/tmp"/*-raw.tgz "${REPO_PARENT}/stemcell/${raw_stemcell_filename}"

  meta4 import-file --metalink="$meta4_path" --version="$CANDIDATE_BUILD_NUMBER" "${REPO_PARENT}/stemcell/${raw_stemcell_filename}"
  meta4 file-set-url --metalink="$meta4_path" --file="${raw_stemcell_filename}" "https://${S3_API_ENDPOINT}/${STEMCELL_BUCKET}/${IAAS}/${raw_stemcell_filename}"
fi

stemcell_filename="${stemcell_name}.tgz"
mv "${REPO_PARENT}/bosh-linux-stemcell-builder/tmp/${stemcell_filename}" "${REPO_PARENT}/stemcell/${stemcell_filename}"

meta4 import-file --metalink="$meta4_path" --version="$CANDIDATE_BUILD_NUMBER" "${REPO_PARENT}/stemcell/${stemcell_filename}"
meta4 file-set-url --metalink="$meta4_path" --file="${stemcell_filename}" "https://${S3_API_ENDPOINT}/${STEMCELL_BUCKET}/${IAAS}/${stemcell_filename}"

# just in case we need to debug/verify the live results
cat "$meta4_path"

cd "${REPO_PARENT}/stemcells-index-output"

git add -A
git config --global user.email "ci@localhost"
git config --global user.name "CI Bot"
git commit -m "dev: $OS_NAME-$OS_VERSION/$CANDIDATE_BUILD_NUMBER ($IAAS-$HYPERVISOR)"
