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
