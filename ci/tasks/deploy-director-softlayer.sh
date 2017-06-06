#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

function cp_artifacts {
   mv $HOME/.bosh director-state/
   cp director.yml director-creds.yml director-state.json director-state/
}
trap cp_artifacts EXIT

export BOSH_sl_datacenter=$(fromEnvironment '.network1.softlayerDatacenter')
export BOSH_internal_cidr=$(fromEnvironment '.network1.softlayerCIDR')
export BOSH_internal_gw=$(fromEnvironment '.network1.softlayerGateway')
export BOSH_internal_ip=$(fromEnvironment '.network1.softlayerDirector')
export BOSH_sl_vlan_public=$(fromEnvironment '.network1.softlayerPublicVLAN')
export BOSH_sl_vlan_private=$(fromEnvironment '.network1.softlayerPrivateVLAN')
export BOSH_reserved_range="[$(fromEnvironment '.network1.reservedRange')]"
export BOSH_internal_static_ips="[$(fromEnvironment '.network1.softlayerStaticIPs')]"

cat > director-creds.yml <<EOF
internal_ip: $BOSH_internal_ip
EOF


export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

$bosh_cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/softlayer/cpi.yml \
  --vars-store director-creds.yml \
  -v director_name=stemcell-smoke-tests-director \
  -v sl_vm_name_prefix=$SL_VM_NAME_PREFIX \
  -v sl_vm_domain=$SL_VM_DOMAIN \
  -v sl_director_fqn=$SL_VM_NAME_PREFIX.$SL_VM_DOMAIN \
  -v sl_username=$SL_USERNAME \
  -v sl_api_key=$SL_API_KEY \
  --vars-env "BOSH" > director.yml

$bosh_cli create-env director.yml -l director-creds.yml

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`$bosh_cli int director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`$bosh_cli int director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET=`$bosh_cli int director-creds.yml --path /admin_password`

$bosh_cli -n update-cloud-config bosh-deployment/softlayer/cloud-config.yml \
          --ops-file bosh-linux-stemcell-builder/ci/assets/reserve-ips.yml \
          -v sl_vm_name_prefix=$SL_VM_NAME_PREFIX_2 \
          -v sl_vm_domain=$SL_VM_DOMAIN \
          -v sl_public_ssh_key=$SL_PUBLIC_SSH_KEY \
          -v powerdns_ip=$BOSH_ENVIRONMENT \
          -v sl_vlan_public_id=$SL_VLAN_PUBLIC \
          -v sl_vlan_private_id=$SL_VLAN_PRIVATE \
          --vars-env "BOSH"
