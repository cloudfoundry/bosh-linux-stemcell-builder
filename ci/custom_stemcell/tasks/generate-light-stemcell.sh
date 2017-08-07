#!/usr/bin/env bash

set -e

echo -e "Set up softlayer cli login"
cat <<EOF > ~/.softlayer
[softlayer]
username = ${SL_USERNAME}
api_key = ${SL_API_KEY}
endpoint_url = https://api.softlayer.com/xmlrpc/v3.1/
timeout = 0
EOF
#echo "nameserver 114.114.114.114" > /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo -e "\n Get stemcell version..."
stemcell_version=$(cat version/number | sed 's/\.0$//;s/\.0$//')
stemcell_id=`cat stemcell-info/stemcell-info-${stemcell_version}.json`
echo -e "Get UUID of stemcell ${stemcell_id}"
stemcell_uuid=`slcli image detail ${stemcell_id} | grep global_identifier | tr -s [:space:] | cut -d " " -f 2`

# outputs
output_dir="light-stemcell"
mkdir -p ${output_dir}

pushd ${output_dir}
echo -e "Compose stemcell.MF"
cat <<EOF > stemcell.MF
name: bosh-bluemix-xen-ubuntu-trusty-go_agent
version: "${stemcell_version}"
bosh_protocol: 1
sha1: MTYxMzE1MTplYWNlZDU0Ni04ODU4LTRhZWMtYmE0Yy01NmYxZTgzMjExNGTaOaPuXmtLDTJVv++VYBiQr9gHCQ==
operating_system: ${OS_NAME}-${OS_VERSION}
cloud_properties:
  infrastructure: ${IAAS}
  architecture: x86_64
  root_device_name: /dev/xvda
  version: "${stemcell_version}"
  virtual-disk-image-id: ${stemcell_id}
  virtual-disk-image-uuid: ${stemcell_uuid}
  datacenter-name: lon02
EOF

echo -e "Compress light stemcell tgz file"
touch image
stemcell_filename=light-bosh-stemcell-${stemcell_version}-${IAAS}-${HYPERVISOR}-${OS_NAME}-${OS_VERSION}-go_agent.tgz

tar zcvf $stemcell_filename image stemcell.MF
checksum="$(sha1sum "${stemcell_filename}" | awk '{print $1}')"

fileUrl=https://s3-api.us-geo.objectstorage.softlayer.net/bosh-softlayer-custom-bluemix-stemcell-candidate/${stemcell_filename}
echo -e "Stemcell Download URL -> ${fileUrl}"
sha1=`curl -L ${fileUrl} | sha1sum | cut -d " " -f 1`
echo -e "Sha1 hashcode -> $checksum"

popd
