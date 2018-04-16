#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ ${DISTRIB_CODENAME} == 'trusty' ]; then
  cat >> $chroot/etc/init/ttyS0.conf <<EOS
# ttyS0 - getty
#
# This service maintains a getty on ttyS0 from the point the system is
# started until it is shut down again.

start on stopped rc RUNLEVEL=[12345]
stop on runlevel [!12345]

pre-start script
    # getty will not be started if the serial console is not present
    stty -F /dev/ttyS0 -a 2> /dev/null > /dev/null || { stop; exit 0; }
end script

respawn
script
    exec /sbin/getty -L ttyS0 115200 vt102
end script
EOS
fi
