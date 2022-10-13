source $base_dir/lib/prelude_common.bash
source $base_dir/lib/helpers.sh

work=$1
chroot=${chroot:=$work/chroot}
mkdir -p $work $chroot

# Source settings if present
if [ -f $settings_file ]
then
  source $settings_file
fi

# Source /etc/lsb-release if present
if [ -f $chroot/etc/lsb-release ]
then
  source $chroot/etc/lsb-release
else
  export DISTRIB_CODENAME="no-distrib-codename"
fi

function get_os_type {
  centos_file=$chroot/etc/centos-release
  rhel_file=$chroot/etc/redhat-release
  ubuntu_file=$chroot/etc/lsb-release
  photonos_file=$chroot/etc/photon-release
  opensuse_file=$chroot/etc/SuSE-release

  os_type=''
  if [ -f $photonos_file ]
  then
    os_type='photonos'
  elif [ -f $ubuntu_file ]
  then
    os_type='ubuntu'
  elif [ -f $centos_file ]
  then
    os_type='centos'
  elif [ -f $rhel_file ]
  then
    os_type='rhel'
  elif [ -f $opensuse_file ]
  then
    os_type='opensuse'
  fi

  echo $os_type
}

os_type=$(get_os_type)
export OS_TYPE=$os_type

function pkg_mgr {
  os_type=$(get_os_type)

  if [ "${os_type}" == 'ubuntu' ]
  then
    run_in_chroot $chroot "apt-get update"
    run_in_chroot $chroot "export DEBIAN_FRONTEND=noninteractive;apt-get -f -y --force-yes --no-install-recommends $*"
    run_in_chroot $chroot "apt-get clean"
  elif [ "${os_type}" == 'centos' -o "${os_type}" == 'rhel' -o "${os_type}" == 'photonos' ]
  then
    run_in_chroot $chroot "yum --verbose --assumeyes $*"
    run_in_chroot $chroot "yum clean all"
  elif [ "${os_type}" == 'opensuse' ]
  then
    run_in_chroot $chroot "zypper -n $*"
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}

# checks if an OS package with the given name exists in the current database of available packages.
# returns 0 if package exists (whether or not is is installed); 1 otherwise
function pkg_exists {
  os_type=$(get_os_type)

  if [ "${os_type}" == 'ubuntu' ]
  then
    run_in_chroot $chroot "apt-get update"
    result=`run_in_chroot $chroot "if apt-cache show $1 2>/dev/null >/dev/null; then echo exists; else echo does not exist; fi"`
    if [[ "$result" == *"exists"* ]]; then
      return 0
    else
      return 1
    fi
  elif [ "${os_type}" == 'centos' -o "${os_type}" == 'rhel' -o "${os_type}" == 'photonos' ]
  then
    result=`run_in_chroot $chroot "if yum list $1 2>/dev/null >/dev/null; then echo exists; else echo does not exist; fi"`
    if [[ "$result" == *"exists"* ]]; then
      return 0
    else
      return 1
    fi
  elif [ "${os_type}" == 'opensuse' ]
  then
    result=`run_in_chroot $chroot "if zypper se $1 2>/dev/null >/dev/null; then echo exists; else echo does not exist; fi"`
    if [ "$result" == 'exists' ]; then
      return 0
    else
      return 1
    fi
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}

function esm_enable {
  pkg_mgr install ca-certificates
  pkg_mgr install ubuntu-advantage-tools
  run_in_chroot $chroot "ua attach ${ESM_TOKEN} --no-auto-enable"
  run_in_chroot $chroot "ua enable esm-infra"
  run_in_chroot $chroot "chmod a-x,o-w /tmp/ubuntu-advantage/candidate-version"
}

function esm_disable {
  run_in_chroot $chroot "ua detach --assume-yes"
  pkg_mgr --purge --auto-remove remove ubuntu-advantage-tools
  run_in_chroot $chroot "rm -f /tmp/ubuntu-advantage/candidate-version"
}
