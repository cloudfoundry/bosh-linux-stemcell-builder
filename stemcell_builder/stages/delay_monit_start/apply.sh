#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# /sbin is symlinked to /usr/sbin on Ubuntu
runsvstart_dir="usr/sbin/runsvdir-start"

# if /var/vcap/data/sys/run is not already mounted, the agent must not have been started yet
# in that case remove /etc/services/monit in order to prevent runsvdir from starting monit (the agent will do that during boostrapping)
sed -i '2i if [ x`mount | grep -c /var/vcap/data/sys/run` = x0 ] ; then rm -f /etc/service/monit ; fi' "${chroot}/${runsvstart_dir}"
