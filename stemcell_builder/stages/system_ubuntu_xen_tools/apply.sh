#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
source "$base_dir/lib/prelude_apply.bash"
source "$base_dir/etc/settings.bash"

debs="xe-guest-utilities xenstore-utils"

pkg_mgr install $debs

set -u

# xen-tools configuration
file=${chroot}/etc/sysctl.conf
sed -i -e 's/\(^\s*net\.ipv4\.conf\.[^.]\+\.arp_notify\s*=\s*0\)/#Auto-disabled by xs-tools:install.sh\n#\1/' "${file}"
printf '# Auto-enabled by xs-tools:install.sh\nnet.ipv4.conf.all.arp_notify = 1\n' >> "${file}"
