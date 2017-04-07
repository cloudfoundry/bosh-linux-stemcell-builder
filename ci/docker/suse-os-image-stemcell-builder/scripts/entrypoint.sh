#!/bin/bash

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback

USER_ID=${LOCAL_USER_ID:-1000}

echo "Starting with UID : $USER_ID"
useradd --shell /bin/bash -u $USER_ID -o -c "" -m opensuse
export HOME=/home/opensuse


echo 'opensuse ALL=NOPASSWD:ALL' >> /etc/sudoers
usermod -G users,rvm opensuse
mkdir /mnt/stemcells && chown opensuse /mnt/stemcells

udevd --daemon

echo "
Welcome to the awesome stemcell builder!

First bundle the gems:

bundle install --local

To build the os image run:

export SKIP_UID_CHECK=1
mkdir -p /opt/bosh/tmp
bundle exec rake stemcell:build_os_image[opensuse,leap,/opt/bosh/tmp/os_leap_base_image.tgz]

Afterwards you can build the stemcell like this:

export BOSH_MICRO_ENABLED=no
bundle exec rake stemcell:build_with_local_os_image[openstack,kvm,opensuse,leap,/opt/bosh/tmp/os_leap_base_image.tgz]
"

exec /usr/local/bin/gosu opensuse "$@"
