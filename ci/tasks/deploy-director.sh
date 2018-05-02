#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby ruby

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

export BOSH_internal_cidr=$(fromEnvironment '.network1.vCenterCIDR')
export BOSH_internal_gw=$(fromEnvironment '.network1.vCenterGateway')
export BOSH_internal_ip=$(fromEnvironment '.network1["staticIP-1"]')
export BOSH_network_name=$(fromEnvironment '.network1.vCenterVLAN')
export BOSH_reserved_range="[$(fromEnvironment '.network1.reservedRange')]"
export BOSH_stemcell_path=$(realpath stemcell/*.tgz)

cat > director-creds.yml <<EOF
internal_ip: $BOSH_internal_ip
EOF

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

$bosh_cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/vsphere/cpi.yml \
  -o bosh-deployment/vsphere/resource-pool.yml \
  -o bosh-linux-stemcell-builder/ci/assets/local-stemcell.yml \
  --vars-store director-creds.yml \
  -v director_name=stemcell-smoke-tests-director \
  --vars-env "BOSH" > director.yml

$bosh_cli create-env director.yml -l director-creds.yml

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`$bosh_cli int director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`$bosh_cli int director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$bosh_cli int director-creds.yml --path /admin_password`

$bosh_cli -n update-cloud-config bosh-deployment/vsphere/cloud-config.yml \
          --ops-file bosh-linux-stemcell-builder/ci/assets/reserve-ips.yml \
          --vars-env "BOSH"

mv $HOME/.bosh director-state/
mv director.yml director-creds.yml director-state.json director-state/
