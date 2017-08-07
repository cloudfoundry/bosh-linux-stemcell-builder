#!/usr/bin/env bash

set -x

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

custom_stemcell_version=$( cat version/number | sed 's/\.0$//;s/\.0$//' )
echo -e "Capture the VM ${stemcell_vm_id} to a private image"
if [ `slcli image list | grep "Template created from imported bosh-stemcell-${custom_stemcell_version}-bluemix-esxi-ubuntu-trusty-go_agent.vhd" | wc -l` -gt 0 ]; then
  echo -e "The image with name 'Template created from imported bosh-stemcell-${custom_stemcell_version}-bluemix-esxi-ubuntu-trusty-go_agent.vhd' already exists, exiting..."
  exit 1
fi

slcli vs capture -n "Template created from imported bosh-stemcell-${custom_stemcell_version}-bluemix-esxi-ubuntu-trusty-go_agent.vhd" "${stemcell_vm_id}"
if [ $? -ne 0 ]; then
  echo -e "The image capture failed, exiting..."
fi
sleep 10

capture_success=false
for (( i=1; i<=60; i++ ))
do
  slcli vs detail ${stemcell_vm_id} | grep RUNNING > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "The image capture transaction is not completed yet, waiting 10 more seconds..."
    sleep 10
  else
    echo -e "The image capture transaction is completed"
    capture_success=true
    break
  fi
done

if [ "${capture_success}" = false ]; then
  echo -e "The image capture failed after 600 seconds, please check VM ${stemcell_vm_id} status"
  exit 1
fi

private_image_id=`slcli image list --name "Template created from imported bosh-stemcell-${custom_stemcell_version}-bluemix-esxi-ubuntu-trusty-go_agent.vhd" | tail -f | cut -d " " -f 1`

echo -e "Convert the private image ${private_image_id} to a public image"
sleep 5
curl -X POST -d "{
  \"parameters\":
  [
    \"light-bosh-stemcell-${custom_stemcell_version}-bluemix-xen-ubuntu-trusty-go_agent\",
    \"Public_light_stemcell_${custom_stemcell_version}\",
    \"Public_light_stemcell_${custom_stemcell_version}\",
    [
      {
          \"id\":358694,
          \"longName\":\"London 2\",
          \"name\":\"lon02\"
      }
    ]
  ]
}" https://${SL_USERNAME}:${SL_API_KEY}@api.softlayer.com/rest/v3.1/SoftLayer_Virtual_Guest_Block_Device_Template_Group/${private_image_id}/createPublicArchiveTransaction >> stemcell-image/stemcell-info-${custom_stemcell_version}.json

sleep 20
stemcell_id=$(cat stemcell-image/stemcell-info-${custom_stemcell_version}.json | sed 's/\.0$//;s/\.0$//')
convert_success=false
for (( i=1; i<=60; i++ ))
do
  slcli image detail ${stemcell_id} | grep 'active_transaction  NULL' > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "The image conversion transaction is not completed yet, waiting 10 more seconds..."
    sleep 10
  else
    echo -e "The image conversion transaction is completed"
    convert_success=true
    break
  fi
done

if [ "${convert_success}" = false ]; then
  echo -e "The image conversion to public failed after 600 seconds, please check image ${stemcell_id} status"
  exit 1
fi

echo -e "Enable HVM mode for the public stemcell ${stemcell_id}"
hvm_enabled=`curl -sk https://${SL_USERNAME}:${SL_API_KEY}@api.softlayer.com/rest/v3/SoftLayer_Virtual_Guest_Block_Device_Template_Group/${stemcell_id}/setBootMode/HVM.json`
if [ "${hvm_enabled}" != true ]; then
  echo -e "Enabling HVM mode on the stemcell ${stemcell_id} failed"
  exit 1
fi
