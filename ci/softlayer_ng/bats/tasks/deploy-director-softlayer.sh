#!/usr/bin/env bash

source /etc/profile.d/chruby.sh
chruby ruby

function cp_artifacts {
  mv $HOME/.bosh director-state/
  cp director.yml director-creds.yml director-state.json director-state/
}

trap cp_artifacts EXIT

: ${BAT_INFRASTRUCTURE:?}

mv bosh-cli/bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

powerdns_yml_path=$(find ${pwd} -name powerdns.yml | head -n 1)
bosh-cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/$BAT_INFRASTRUCTURE/cpi.yml \
  -o ${powerdns_yml_path} \
  -o bosh-deployment/jumpbox-user.yml \
  -o bosh-linux-stemcell-builder/ci/bats/ops/remove-health-monitor.yml \
  -v dns_recursor_ip=8.8.8.8 \
  -v director_name=bats-director \
  -v sl_director_fqn=$BOSH_SL_VM_NAME_PREFIX.$BOSH_SL_VM_DOMAIN \
  --vars-file <( bosh-linux-stemcell-builder-master/ci/bats/iaas/$BAT_INFRASTRUCTURE/director-vars ) \
  > director.yml

echo '========================================='
cat director.yml
echo '========================================='

bosh-cli create-env \
  --state director-state.json \
  --vars-store director-creds.yml \
  director.yml
