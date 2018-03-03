#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Configure the Google guest environment
# https://github.com/GoogleCloudPlatform/compute-image-packages#configuration
cp $assets_dir/instance_configs.cfg.template $chroot/etc/default/

mkdir -p $chroot/tmp/google

os_type="$(get_os_type)"
if [ "${os_type}" == "ubuntu" ]
then
  if [ "${DISTRIB_CODENAME}" == "trusty" ]; then
    # Copy google daemon packages into chroot
    cp -R $assets_dir/google-ubuntu/*.deb $chroot/tmp/google/

    run_in_chroot $chroot "apt-get update"
    run_in_chroot $chroot "apt-get install -y python-setuptools python-boto"
    run_in_chroot $chroot "dpkg --unpack /tmp/google/*.deb"
    run_in_chroot $chroot "rm /var/lib/dpkg/info/google-compute-engine-init-trusty.postinst"
    run_in_chroot $chroot "dpkg --configure google-compute-engine-init-trusty google-config-trusty google-compute-engine-trusty"
    run_in_chroot $chroot "apt-get install -yf"
  elif [ "${DISTRIB_CODENAME}" == "xenial" ]; then
    run_in_chroot $chroot "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"

    run_in_chroot $chroot "tee /etc/apt/sources.list.d/google-cloud.list << EOM
deb http://packages.cloud.google.com/apt google-compute-engine-stretch-stable main
deb http://packages.cloud.google.com/apt google-cloud-packages-archive-keyring-stretch main
EOM"

    pkg_mgr install "google-cloud-packages-archive-keyring"
    pkg_mgr install "--target-release google-compute-engine-stretch-stable python-google-compute-engine python3-google-compute-engine"
    pkg_mgr install "google-compute-engine-oslogin google-compute-engine"

    run_in_chroot $chroot "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python3/dist-packages/google_compute_engine/metadata_watcher.py"
  fi

  # Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
  run_in_chroot $chroot "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/dist-packages/google_compute_engine/metadata_watcher.py"
elif [ "${os_type}" == "rhel" -o "${os_type}" == "centos" ]
then
  # Copy google daemon packages into chroot
  cp -R $assets_dir/google-centos/*.rpm $chroot/tmp/google/

  run_in_chroot $chroot "yum install -y python-setuptools python-boto"

  run_in_chroot $chroot "yum --nogpgcheck install -y /tmp/google/*.rpm"

  # Hack: replace google metadata hostname with ip address (bosh agent might set a dns that it's unable to resolve the hostname)
  run_in_chroot $chroot "sed -i 's/metadata.google.internal/169.254.169.254/g' /usr/lib/python2.7/site-packages/google_compute_engine/metadata_watcher.py"
else
  echo "Unknown OS '${os_type}', exiting"
  exit 2
fi

# See https://github.com/cloudfoundry/bosh/issues/1399 for context
run_in_chroot $chroot "rm -f /etc/dhcp/dhclient-exit-hooks.d/set_hostname"

