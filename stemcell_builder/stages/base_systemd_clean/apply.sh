#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# only load minimal set of systemd units / services
# https://github.com/asg1612/docker-systemd/blob/master/Dockerfile
run_in_chroot "${chroot}" "
find /etc/systemd/system /lib/systemd/system \
  -path '*.wants/*' \
  -not -name '*firstboot*' \
  -not -name '*bosh-agent*' \
  -not -name 'cron*' \
  -not -name 'monit*' \
  -not -name '*dbus*' \
  -not -name '*journald*' \
  -not -name '*logrotate*' \
  -not -name '*runit*' \
  -not -name '*ssh*' \
  -not -name '*systemd-user-sessions*' \
  -not -name '*systemd-tmpfiles*' \
  -print \
  -exec rm -f {} \\;
"
