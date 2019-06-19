#!/bin/bash

stemcell_filepath=$1

tar xvf "./${stemcell_filepath}"
tar xzvf "./image"

# should leave behind a "image-disk1.vmdk"
qemu-img convert -f vmdk -O raw image-disk1.vmdk image.img

file image.img
echo "yay"
