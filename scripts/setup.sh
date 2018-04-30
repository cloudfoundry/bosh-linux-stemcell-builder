#!/bin/bash

function setup() {
  pushd ci/docker/os-image-stemcell-builder
    vagrant up
    vagrant ssh -c
  popd
}

setup
