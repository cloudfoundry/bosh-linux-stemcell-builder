#!/bin/bash -ex

source /etc/profile.d/chruby.sh
chruby ruby

set +e
#create user for ShelloutTypes::File tests
chroot /tmp/ubuntu-chroot /bin/bash -c 'useradd -G nogroup shellout'
set -e

echo -e "\n\033[32m[INFO] Unit Testing packages.\033[0m"
pushd bosh-linux-stemcell-builder
  bundle install --local

  pushd bosh-stemcell
    bundle exec rspec spec/
    bundle exec rspec spec/ --tag shellout_types
  popd
popd
