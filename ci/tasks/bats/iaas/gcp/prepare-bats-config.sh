#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../../.." && pwd )"
REPO_PARENT="$( cd "${REPO_ROOT}/.." && pwd )"

if [[ -n "${DEBUG:-}" ]]; then
  set -x
  export BOSH_LOG_LEVEL=debug
  export BOSH_LOG_PATH="${BOSH_LOG_PATH:-${REPO_PARENT}/bosh-debug.log}"
fi

manifest_path() { bosh int "${REPO_PARENT}/director-state/director.yml" --path="$1" ; }
creds_path() { bosh int "${REPO_PARENT}/director-state/director-creds.yml" --path="$1" ; }

director_ip=$( manifest_path /instance_groups/name=bosh/networks/name=default/static_ips/0 )
gateway_username=$( manifest_path "/instance_groups/0/jobs/name=user_add/properties/users/0/name" )
ssh_private_key=$( creds_path /jumpbox_ssh/private_key | sed 's/$/\\n/' | tr -d '\n' )

cat > "${REPO_PARENT}/bats-config/bats.env" <<EOF
export BOSH_ENVIRONMENT="${director_ip}"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"

private_key_path=\$(mktemp)
echo -e "${ssh_private_key}" > \${private_key_path}

export BOSH_ALL_PROXY="ssh+socks5://${gateway_username}@${director_ip}:22?private-key=\${private_key_path}"

export BAT_INFRASTRUCTURE=gcp

export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~multiple_manual_networks --tag ~root_partition --tag ~raw_ephemeral_storage"
EOF

cat > "${REPO_PARENT}/interpolate.yml" <<EOF
---
cpi: google
properties:
  availability_zone: ((AVAILABILITY_ZONE))
  zone: ((ZONE))
  preemptible: ((PREEMPTIBLE))
  pool_size: 1
  instances: 1
  machine_type: ((MACHINE_TYPE))
  second_static_ip: ((STATIC_IP_DEFAULT-2))
  ssh_gateway:
    host: "${director_ip}"
    username: "${gateway_username}"
  ssh_key_pair:
    public_key: "$( creds_path /jumpbox_ssh/public_key )"
    private_key: "${ssh_private_key}"
  stemcell:
    name: ((STEMCELL_NAME))
    version: latest
  networks:
    - name: default
      type: manual
      static_ip: ((STATIC_IP_DEFAULT)) # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
      subnets:
      - range: ((CIDR_DEFAULT))
        static: ((STATIC_DEFAULT))
        gateway: ((GATEWAY_DEFAULT))
        cloud_properties:
          network_name: ((NETWORK_DEFAULT))
          subnetwork_name: ((SUBNETWORK_DEFAULT))
          ephemeral_external_ip: false
        dns: [8.8.8.8]
EOF

bosh interpolate \
 --vars-env VARS \
 "${REPO_PARENT}/interpolate.yml" \
 > "${REPO_PARENT}/bats-config/bats-config.yml"
