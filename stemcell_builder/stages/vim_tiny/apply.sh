#!/usr/bin/env bash
set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# TODO: https://bugs.launchpad.net/ubuntu/+source/vim/+bug/1968912 until this is solved we will provide the vim-runtime package
pkg_mgr install "vim-runtime"

run_in_chroot $chroot "sudo ln -s /usr/bin/vim.tiny /usr/bin/vim"