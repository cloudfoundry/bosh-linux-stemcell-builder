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

# Mark /opt/bosh as a safe git repo to avoid "fatal: unsafe repository ('/opt/bosh' is owned by someone else)"
git config --global --add safe.directory /opt/bosh

function pkg_mgr {
  run_in_chroot $chroot "apt-get update"
  run_in_chroot $chroot "export DEBIAN_FRONTEND=noninteractive;apt-get -f -y --no-install-recommends $*"
  run_in_chroot $chroot "apt-get clean"
}

# checks if an OS package with the given name exists in the current database of available packages.
# returns 0 if package exists (whether or not is is installed); 1 otherwise
function pkg_exists {
  run_in_chroot $chroot "apt-get update"
  result=`run_in_chroot $chroot "if apt-cache show $1 2>/dev/null >/dev/null; then echo exists; else echo does not exist; fi"`
  if [[ "$result" == *"exists"* ]]; then
    return 0
  else
    return 1
  fi
}

function update_kernel_static_libraries {
  kernel_suffix=${1}
  major_kernel_version=${2}

  suffix=$kernel_suffix
  if [ ! -z "$UBUNTU_FIPS_USE_IAAS_KERNEL" ]; then
    suffix=-$stemcell_infrastructure$kernel_suffix
  fi
  kernel_version=$(find $chroot/usr/src/ -name "linux-headers-$major_kernel_version.*$kernel_suffix" | grep -o "[0-9].*-[0-9]*$suffix")
  sed -i "s/__KERNEL_VERSION__/$kernel_version/g" $chroot/var/vcap/bosh/etc/static_libraries_list

  # since kernel 6.5 the objtool/libsubcmd.a has been moved to objtool/libsubcmd/libsubcmd.a
  # fips still uses the 5.9 kernel, so we need to rewrite the static_libraries_list file to the old path
  # TODO: puting a todo tag here as this could probably be removed in the future if the kernel version gets bumped
  if [[ "${stemcell_operating_system_variant}" == 'fips' ]]; then
    sed -i "s|objtool/libsubcmd/libsubcmd.a|objtool/libsubcmd.a|g" $chroot/var/vcap/bosh/etc/static_libraries_list
  fi
}
