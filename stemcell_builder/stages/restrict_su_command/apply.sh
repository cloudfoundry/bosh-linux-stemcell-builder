#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# CIS-9.5: restrict access to the su command via pam_wheel.
# pam_wheel.so use_uid requires the calling user to be in the wheel group.
# Ubuntu does not ship a wheel group, so we create it and add root + vcap.
run_in_chroot $chroot "
  groupadd -f wheel
  usermod -aG wheel root
  usermod -aG wheel,sudo vcap
  echo 'auth required pam_wheel.so use_uid' >> /etc/pam.d/su
"
