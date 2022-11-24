#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
source "$base_dir/lib/prelude_apply.bash"
source "$base_dir/etc/settings.bash"

# repository information
# - for some reason, xe-guest-utilities@v7.31.0 build process creates
#   a tarball with named with a different version
ns="xenserver"
repo="xe-guest-utilities"
tag="v7.30.0"
tarball="xe-guest-utilities_6.6.80-0_x86_64.tgz"

dir=$(mktemp -d)

# xen-tools sources
# - the build process requires the directory name to be xe-guest-utilities
mkdir "${dir}/${repo}"
cd "${dir}/${repo}"
curl -fsSL https://github.com/${ns}/${repo}/archive/refs/tags/${tag}.tar.gz | \
  tar xvz --strip-components=1

# xen-tools compilation
go mod vendor
mkdir vendor/${repo}
make build

# xen-tools installation
tar xvzf ${dir}/${repo}/build/dist/${tarball} -C ${chroot}/

# xen-tools configuration
file=${chroot}/etc/sysctl.conf
sed -i -e 's/\(^\s*net\.ipv4\.conf\.[^.]\+\.arp_notify\s*=\s*0\)/#Auto-disabled by xs-tools:install.sh\n#\1/' "${file}"
printf '# Auto-enabled by xs-tools:install.sh\nnet.ipv4.conf.all.arp_notify = 1\n' >> "${file}"
