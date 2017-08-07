#!/usr/bin/env bash

set -eu

export BOSH_BINARY_PATH=$(realpath bosh-cli/bosh-cli-*)
chmod +x $BOSH_BINARY_PATH
export BOSH_ENVIRONMENT=`$BOSH_BINARY_PATH int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`$BOSH_BINARY_PATH int director-state/director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$BOSH_BINARY_PATH int director-state/director-creds.yml --path /admin_password`
export SYSLOG_RELEASE_PATH=$(realpath syslog-release/*.tgz)
export STEMCELL_PATH=$(realpath stemcell/*.tgz)
export BOSH_stemcell_version=\"$(realpath stemcell/version | xargs -n 1 cat)\"

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke
  popd
popd
