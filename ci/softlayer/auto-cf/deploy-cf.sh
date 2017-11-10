#!/usr/bin/env bash
set -e

: ${DEPLOYMENT_NAME:?}
: ${SYSTEM_DOMAIN:?}

deployment_dir="${PWD}/deployment"
mkdir -p $deployment_dir

tar -zxvf director-artifacts/director_artifacts.tgz -C ${deployment_dir}

cp ${deployment_dir}/bosh-cli* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

echo -e "\n\033[32m[INFO] Verifying the director environment.\033[0m"
cat ${deployment_dir}/director-hosts >>/etc/hosts
export BOSH_ENVIRONMENT=$(awk '{if ($2!="") print $2}' ${deployment_dir}/director-hosts)
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh-cli int ${deployment_dir}/director-creds.yml --path /admin_password)
export BOSH_CA_CERT=$(bosh-cli int ${deployment_dir}/director-creds.yml --path /default_ca/ca)
bosh-cli login

echo -e "\n\033[32m[INFO] Uploading stemcell.\033[0m"
export SOFTLAYER_STEMCELL_VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )
bosh-cli us https://s3.amazonaws.com/bosh-softlayer-stemcells-candidate-container/light-bosh-stemcell-${SOFTLAYER_STEMCELL_VERSION}-softlayer-xen-ubuntu-trusty-go_agent.tgz
cat >specify-stemcell-version.yml << EOF
- path: /stemcells/alias=default/version
  type: replace
  value: ${SOFTLAYER_STEMCELL_VERSION}
EOF

echo -e "\n\033[32m[INFO] Disabling uaa https.\033[0m"
cat >disable-uaa-https.yml << EOF
- type: replace
  path: /instance_groups/name=uaa/jobs/name=uaa/properties/uaa/require_https?
  value: false
EOF

echo -e "\n\033[32m[INFO] Generating cf manifest.\033[0m"
bosh-cli vms >${deployment_dir}/deployed-vms
bosh-cli int cf-deployment/cf-deployment.yml \
	--vars-store ${deployment_dir}/cf-creds.yml \
	-o cf-deployment/operations/rename-deployment.yml \
	-o cf-deployment/operations/softlayer/add-blobstore-access-rules.yml \
	-o ./specify-stemcell-version.yml \
	-o ./disable-uaa-https.yml \
	-o cf-deployment/operations/softlayer/downsize-cf.yml \
	-o cf-deployment/operations/community/use-haproxy.yml \
	-v deployment_name=${DEPLOYMENT_NAME} \
	-v system_domain=${SYSTEM_DOMAIN} \
	>${deployment_dir}/cf.yml

export BOSH_LOG_LEVEL=DEBUG
export BOSH_LOG_PATH=./run.log

echo -e "\n\033[32m[INFO] Deploying CF.\033[0m"

cat ${deployment_dir}/cf.yml

bosh-cli -d ${DEPLOYMENT_NAME} -n deploy ${deployment_dir}/cf.yml \
	--vars-store ${deployment_dir}/cf-creds.yml

bosh-cli vms >${deployment_dir}/deployed-vms

echo -e "\n\033[32m[INFO] Saving cf artifacts.\033[0m"
pushd ${deployment_dir}
  tar -zcvf /tmp/cf_artifacts.tgz ./ >/dev/null 2>&1
popd

mv /tmp/cf_artifacts.tgz ./cf-artifacts
