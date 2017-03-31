#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

sed -i 's/umask [0-7]\+/umask 077/' ${chroot}/etc/profile
sed -i 's/umask [0-7]\+/umask 077/' ${chroot}/etc/csh.cshrc
sed -i 's/umask [0-7]\+/umask 077/' ${chroot}/etc/bashrc
