#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

echo '# prevent blacklisted modules from being loaded
install usb-storage /bin/true
install bluetooth /bin/true
install tipc /bin/true
install sctp /bin/true
install dccp /bin/true
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install rds /bin/true' >> $chroot/etc/modprobe.d/blacklist.conf

echo '# prevent nouveau from loading
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off' >> $chroot/etc/modprobe.d/blacklist-nouveau.conf

rm -rf $chroot/lib/modules/*/kernel/zfs $chroot/usr/src/linux-headers-*/zfs
