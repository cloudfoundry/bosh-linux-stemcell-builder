#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

run_firstboot_tasks() {
  rm -f /etc/ssh/ssh_host*key* &&
    dpkg-reconfigure -fnoninteractive -pcritical openssh-server &&
    dpkg-reconfigure -fnoninteractive sysstat
}

# retry on failures with max 5 times
retries=5
while [ "$retries" -gt 0 ]; do
  if run_firstboot_tasks; then
    exit 0
  fi
  retries=$((retries - 1))

  # wait 3 seconds before retrying to avoid system overload
  sleep 3
done

exit 1
