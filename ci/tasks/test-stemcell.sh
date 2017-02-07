#!/usr/bin/env bash

set -exu

export BOSH_BINARY_PATH=$(realpath bosh-cli/bosh-cli-*)
export SYSLOG_RELEASE_PATH=$(realpath syslog-release/*.tgz)
export BOSH_ENVIRONMENT=${DIRECTOR_IP//./-}.sslip.io
export STEMCELL_PATH=$(realpath stemcell/*.tgz)
chmod +x $BOSH_BINARY_PATH

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke
  popd
popd
