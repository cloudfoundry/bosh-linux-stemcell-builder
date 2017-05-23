#!/bin/bash

set -e

state_path() { bosh-cli int director-state/director.yml --path="$1" ; }
creds_path() { bosh-cli int director-state/director-creds.yml --path="$1" ; }

director_state_dir=$(realpath director-state)
director_ip=`cat "${director_state_dir}/director-info"`

cat > bats-config/bats.env <<EOF
export BOSH_ENVIRONMENT="$( state_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null )"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"
export BOSH_GW_HOST="$( state_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null )"
export BOSH_GW_USER="jumpbox"
export BAT_PRIVATE_KEY="$( creds_path /jumpbox_ssh/private_key )"

export BAT_DNS_HOST="$( state_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null )"

export BAT_INFRASTRUCTURE=softlayer
export BAT_NETWORKING=dynamic

export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~manual_networking --tag ~root_partition --tag ~raw_ephemeral_storage"

export BAT_DIRECTOR=${director_ip}
export BAT_DNS_HOST=${director_ip}

export BAT_DEBUG_MODE=true

export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~manual_networking --tag ~root_partition --tag ~raw_ephemeral_storage"
export BAT_DIRECTOR_USER="${BOSH_CLIENT}"
export BAT_DIRECTOR_PASSWORD="${BOSH_CLIENT_SECRET}"


EOF

cat > interpolate.yml <<EOF
---
cpi: softlayer
properties:
  uuid: ${BOSH_UUID}
  pool_size: 1
  instances: 1
  second_static_ip: ${BAT_SECOND_STATIC_IP}
  stemcell:
    name: ((STEMCELL_NAME))
    version: latest
  cloud_properties:
    bosh_ip: ${director_ip}
    public_vlan_id: ${SL_VLAN_PUBLIC}
    private_vlan_id: ${SL_VLAN_PRIVATE}
    vm_name_prefix: ${SL_VM_NAME_PREFIX}
    data_center: ${SL_DATACENTER}
    domain: ${SL_VM_DOMAIN}
  networks:
  - name: default
    type: dynamic
    dns:
    - ${director_ip}
  password: "\$6\$3n/Y5RP0\$Jr1nLxatojY9Wlqduzwh66w8KmYxjoj9vzI62n3Mmstd5mNVnm0SS1N0YizKOTlJCY5R/DFmeWgbkrqHIMGd51"
EOF

bosh-cli interpolate \
 --vars-file environment/metadata \
 -v STEMCELL_NAME=$STEMCELL_NAME \
 interpolate.yml \
 > bats-config/bats-config.yml
