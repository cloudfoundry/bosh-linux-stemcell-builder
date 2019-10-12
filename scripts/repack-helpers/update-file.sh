#!/bin/bash -eux

if [ -t 0 ];then
  echo "USAGE: $0 [file] [destination] <<< mountpoint"
fi

mountpoint=$(cat)
cp $1 $mountpoint/$2
echo $mountpoint
