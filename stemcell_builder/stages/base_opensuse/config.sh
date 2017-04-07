#!/bin/bash
# stemcell_builder/stages/base_opensuse/config.sh
# Configscript for creating the opensuse base os image
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile
echo "Configure image: [$kiwi_iname]..."
baseMount
suseSetupProduct
suseImportBuildKey
suseInsertService sshd
baseSetRunlevel 3
rm -rf /usr/share/doc/packages/*
rm -rf /usr/share/doc/manual/*
rm -rf /opt/kde*
sed -i -e's/^syntax on/" syntax on/' /etc/vimrc
suseConfig
suseRemoveYaST
baseCleanMount

exit 0
