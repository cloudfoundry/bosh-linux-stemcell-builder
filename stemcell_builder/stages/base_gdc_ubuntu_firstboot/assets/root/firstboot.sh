#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

rm -f /etc/ssh/ssh_host*key*

# generate host key
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
dpkg-reconfigure -fnoninteractive sysstat
