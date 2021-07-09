#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
source "$base_dir/lib/prelude_apply.bash"


sudo env http_proxy="${http_proxy:-}" https_proxy="${https_proxy:-}" no_proxy="${no_proxy:-}" \
apt-get install -y uuid-dev
sudo env http_proxy="${http_proxy:-}" https_proxy="${https_proxy:-}" no_proxy="${no_proxy:-}" \
apt-get install -y lbzip2 || true

cd /tmp
rm -rf vhd-util-convert
git clone --depth 1 https://github.com/rubiojr/vhd-util-convert
cd vhd-util-convert
make
sudo cp vhd-util /usr/local/bin/
