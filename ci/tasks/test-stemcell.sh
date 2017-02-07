#!/usr/bin/env bash

set -exu

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)
  export BOSH_BINARY_PATH=$(realpath bosh-cli/bosh-cli-*)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke
  popd
popd
