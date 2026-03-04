#!/bin/sh
set -e

rm -f /etc/ssh/ssh_host*key*
ssh-keygen -A -v

dpkg-reconfigure -fnoninteractive sysstat
