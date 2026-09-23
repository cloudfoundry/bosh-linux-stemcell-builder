#!/usr/bin/env bash

set -e
base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

bpm_version=$(cat $assets_dir/bpm-version)
bpm_tarball=bpm-${bpm_version}-linux-amd64.tar.gz

# A locally built tarball in assets/ (gitignored) wins. That is the prototype
# loop; CI never has one. Point bpm-version and bpm.sha256 at it too, or the
# checksum below fails.
if [ ! -f $assets_dir/$bpm_tarball ]; then
  # Download to a .part file and verify it before it takes the final name, so
  # an interrupted or bad download is never mistaken for a local override.
  bpm_part=$assets_dir/$bpm_tarball.part
  trap 'rm -f $bpm_part' EXIT
  curl -fsSL --retry 3 --retry-delay 2 -o $bpm_part \
    https://github.com/cloudfoundry/bpm-release/releases/download/v${bpm_version}/$bpm_tarball
  bpm_sha256=$(awk -v f="$bpm_tarball" '$2 == f { print $1 }' $assets_dir/bpm.sha256)
  echo "$bpm_sha256  $bpm_part" | sha256sum -c -
  mv $bpm_part $assets_dir/$bpm_tarball
  trap - EXIT
fi
(cd $assets_dir && sha256sum -c bpm.sha256)

# The tarball carries /usr/libexec/bpm, /usr/bin/bpm, the symlink watcher and
# its unit. Keep the chroot's existing /usr directories as they are.
tar -xzf $assets_dir/$bpm_tarball -C $chroot --no-same-owner --no-overwrite-dir
chmod -R go-w $chroot/usr/libexec/bpm

mkdir -p $chroot/var/vcap/jobs/bpm/bin
ln -sfn /usr/bin/bpm $chroot/var/vcap/jobs/bpm/bin/bpm

run_in_chroot $chroot "
# As the agent would create it.
chown root:vcap /var/vcap/jobs
chmod 0750 /var/vcap/jobs

systemctl enable bpm-symlink-watcher.service
"
