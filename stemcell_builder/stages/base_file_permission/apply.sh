#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

chmod 0000 $chroot/etc/gshadow
chown root:root $chroot/etc/gshadow

# PAM >= 1.7 (Ubuntu Resolute) drops CAP_DAC_OVERRIDE in unix_chkpwd before reading
# /etc/shadow, so mode 0000 makes the file unreadable even for root and breaks `su`
# (including `su - vcap` from job pre-start scripts). 0400 keeps the file unreadable by
# group and other while letting root read it via the owner class.
chmod 0400 $chroot/etc/shadow
chown root:root $chroot/etc/shadow

restrict_binary_setuid
