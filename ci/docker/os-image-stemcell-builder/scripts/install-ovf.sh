#!/bin/bash

set -ex

cd /tmp
echo "${OVF_TOOL_INSTALLER_SHA1} /tmp/ovftool_installer.bundle" | sha1sum -c -
chmod a+x ./ovftool_installer.bundle
bash  ./ovftool_installer.bundle --eulas-agreed
rm -rf ./ovftool_installer.bundle /tmp/vmware-root/ /usr/local/bin/more
