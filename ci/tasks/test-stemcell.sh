#!/usr/bin/env bash

set -e

export PATH=usr/local/go/bin:$PATH
export GOPATH=$(pwd)
cd src/github.com/cloudfoundry/stemcell-acceptance-tests
bin/test-smoke
