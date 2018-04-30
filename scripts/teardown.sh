#!/bin/bash

function teardown() {
  pushd ci/docker/os-image-stemcell-builder
    vagrant destroy -f
    vagrant box update
  popd
}

teardown
