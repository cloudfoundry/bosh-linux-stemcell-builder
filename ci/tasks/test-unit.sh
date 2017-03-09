#!/bin/bash -ex

source /etc/profile.d/chruby.sh
chruby 2.3.1

pushd bosh-linux-stemcell-builder
  bundle install --local

  pushd bosh-stemcell
    bundle exec rspec spec/
  popd
popd
