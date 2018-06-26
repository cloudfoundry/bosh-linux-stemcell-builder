#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash


pkg_mgr install open-iscsi

# add 'service iscsid restart' in lib/systemd/system/open-iscsi.service ExecStartPre
if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
    if [ -f $chroot/etc/init.d/open-iscsi ]
    then
      sed "/ExecStartPre=\/bin\/systemctl/a ExecStart=\/etc\/init.d\/iscsid restart" $chroot/lib/systemd/system/open-iscsi.service
      sed -i "/ExecStartPre=\/bin\/systemctl/a ExecStart=\/etc\/init.d\/iscsid restart" $chroot/lib/systemd/system/open-iscsi.service
      sed -i "s/ExecStop=\/lib\/open-iscsi\/umountiscsi.sh/# ExecStop=\/lib\/open-iscsi\/umountiscsi.sh/" $chroot/lib/systemd/system/open-iscsi.service
      run_in_chroot $chroot "
systemctl daemon-reload
"
    fi
  fi
fi
