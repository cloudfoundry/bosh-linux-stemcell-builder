#!/usr/bin/env bash

set -eu

export BOSH_BINARY_PATH=$(realpath bosh-cli/bosh-cli-*)
chmod +x $BOSH_BINARY_PATH

export BOSH_ENVIRONMENT=`$BOSH_BINARY_PATH int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`$BOSH_BINARY_PATH int director-state/director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$BOSH_BINARY_PATH int director-state/director-creds.yml --path /admin_password`
export SYSLOG_RELEASE_PATH=$(realpath syslog-release/*.tgz)
export OS_CONF_RELEASE_PATH=$(realpath os-conf-release/*.tgz)
export STEMCELL_PATH=$(realpath stemcell/*.tgz)
export BOSH_stemcell_version=\"$(realpath stemcell/version | xargs -n 1 cat)\"

if $BOSH_BINARY_PATH int director-state/director-creds.yml --path /jumpbox_ssh > /dev/null 2>&1 ; then
  jumpbox_private_key=$(mktemp)
  $BOSH_BINARY_PATH int director-state/director-creds.yml --path /jumpbox_ssh/private_key > ${jumpbox_private_key}
  chmod 0600 ${jumpbox_private_key}
  export BOSH_GW_PRIVATE_KEY=${jumpbox_private_key}
  export BOSH_GW_USER=jumpbox
  export BOSH_GW_HOST=$BOSH_ENVIRONMENT
fi

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke $package
  popd
popd
