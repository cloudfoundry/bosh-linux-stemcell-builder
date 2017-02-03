#!/bin/bash

export IAAS=vbox
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(gobosh -e vbox int ~/workspace/bosh-deployment/vbox/creds.yml --path /admin_password)
export BOSH_ENVIRONMENT=https://192.168.50.6:25555
export BOSH_CA_CERT=$(gobosh -e vbox int ~/workspace/bosh-deployment/vbox/creds.yml --path /director_ssl/ca)
export BOSH_VSPHERE_VCENTER_CLUSTER=fiveone
export BOSH_VSPHERE_VCENTER_DC=fiveonedc


ginkgo -r .