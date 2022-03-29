#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

  base_dir=$(readlink -nf $(dirname $0)/../..)
  source $base_dir/lib/prelude_apply.bash
  source $base_dir/lib/prelude_bosh.bash

if [ "${stemcell_operating_system}" == "ubuntu" ]; then
  # Create list of installed packages
  run_in_bosh_chroot $chroot "dpkg -l > packages.out"

  # Export list in stemcell tarball
  cp $chroot/$bosh_dir/packages.out $work/stemcell/packages.txt

elif [ "${stemcell_operating_system}" == "centos" ]; then
   # Create list of installed packages
  run_in_bosh_chroot $chroot "rpm -qa > packages.out"

  # Export list in stemcell tarball
  cp $chroot/$bosh_dir/packages.out $work/stemcell/packages.txt

elif [ "${stemcell_operating_system}" == "opensuse" ]; then
   # Create list of installed packages
  run_in_bosh_chroot $chroot "rpm -qa > packages.out"

  # Export list in stemcell tarball
  cp $chroot/$bosh_dir/packages.out $work/stemcell/packages.txt

fi

cp $chroot/var/vcap/bosh/etc/dev_tools_file_list $work/stemcell/dev_tools_file_list.txt
