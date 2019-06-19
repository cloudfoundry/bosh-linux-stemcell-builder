#!/bin/bash

set -ex

device=$(sudo losetup -a | grep "image.img" | cut -d ':' -f1)
sudo umount /mnt/garbage
sudo losetup -d "${device}"

