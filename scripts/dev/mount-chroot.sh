#!/bin/bash

set -ex

stemcell_image=$1

sudo losetup -fP "${stemcell_image}"
device=$(sudo losetup -a | grep "image.img" | cut -d ':' -f1)
sudo mount -o loop,rw "${device}p1" /mnt/garbage
sudo chroot /mnt/garbage /bin/bash

