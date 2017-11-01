#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ $(get_os_type) == "opensuse" ] ; then
  run_in_chroot $chroot "
    for i in bin daemon lp news uucp games man ftp syslog nobody; do
      usermod -s /bin/false \\\$i
    done
  "
elif ([ $(get_os_type) != 'ubuntu' ] || [ ${DISTRIB_CODENAME} != 'xenial' ]); then
  run_in_chroot $chroot "
    /usr/sbin/usermod -L libuuid
    /usr/sbin/usermod -s /usr/sbin/nologin libuuid
  "
fi
