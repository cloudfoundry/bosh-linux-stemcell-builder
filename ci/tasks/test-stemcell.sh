#!/usr/bin/env bash

set -exu

export BOSH_BINARY_PATH=$(realpath bosh-cli/bosh-cli-*)
chmod +x $BOSH_BINARY_PATH

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke
  popd
popd
