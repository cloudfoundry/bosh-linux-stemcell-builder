#!/bin/bash

set -e -x

env

if [ -z ${stemcell_tgz} ]; then
echo "STEMCELL_LOCATION is not set. export BOSH_DEBUG_PUB_KEY="/home/username/workspace/bosh/bosh-linux-stemcell-builder/tmp/bosh-stemcell-0.0.8-google-kvm-ubuntu-noble-go_agent.tgz""
fi
# if [ -z ${BOSH_DEBUG_PUB_KEY} ]; then
# echo "BOSH_DEBUG_PUB_KEY is not set. export BOSH_DEBUG_PUB_KEY="ssh-rsa blahblah""
# fi

# stemcell_tgz=/tmp/stemcell.tgz
temp_dir=$(mktemp -d)
stemcell_dir=${temp_dir}/stemcell
image_dir=${temp_dir}/image
mkdir -p $stemcell_dir $image_dir
trap 'rm -rf "${temp_dir}"' EXIT

# Repack stemcell
cd $stemcell_dir
tar xvf $stemcell_tgz
new_ver=`date +%s`

# Update stemcell with new agent
cd $image_dir
tar xvf $stemcell_dir/image
mnt_dir=$(mktemp -d)
trap 'rm -rf "${mnt_dir}"' EXIT
sudo mount -o loop,offset=32256 disk.raw $mnt_dir
# echo -n "0.0.${new_ver}" | sudo tee $mnt_dir/var/vcap/bosh/etc/stemcell_version
# cp /tmp/build/*/agent-src/bin/bosh-agent $mnt_dir/var/vcap/bosh/bin/bosh-agent

if [ -n "$BOSH_DEBUG_PUB_KEY" ]; then
    sudo chroot $mnt_dir /bin/bash <<EOF
        useradd -m -s /bin/bash bosh_debug -G bosh_sudoers,bosh_sshers
        cd ~bosh_debug
        mkdir .ssh
        echo $BOSH_DEBUG_PUB_KEY >> .ssh/authorized_keys
        chmod go-rwx -R .
        chown -R bosh_debug:bosh_debug .
EOF
fi

sudo umount $mnt_dir
tar czvf $stemcell_dir/image *

cd $stemcell_dir
# sed -i.bak "s/version: .*/version: 0.0.${new_ver}/" stemcell.MF
tar czvf $stemcell_tgz *

echo "ALL DONE!!!"