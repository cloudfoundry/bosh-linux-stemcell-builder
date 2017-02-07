#!/usr/bin/env bash

set -exu

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke
  popd
popd
