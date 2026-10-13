#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../stages/bosh_audit/shared_functions.bash
source "$base_dir/stages/bosh_audit/shared_functions.bash"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

pkg_mgr install auditd

chroot="$base_dir/../../work/work/chroot"
# From bosh_audit_ubuntu stage, with patch to specifically remove the setting of
# "systemctl disable auditd.service" for GDC.
cp "$chroot/lib/systemd/system/auditd.service" "$chroot/etc/systemd/system/auditd.service"
sed -i "/#ExecStartPost=-\/sbin\/augenrules --load/s/^#//g" "$chroot/etc/systemd/system/auditd.service"
sed -i "/ExecStartPost=-\/sbin\/auditctl -R \/etc\/audit\/audit.rules/s/^/#/g" "$chroot/etc/systemd/system/auditd.service"
run_in_bosh_chroot "$chroot" "chown root:root /var/log/audit"

write_shared_audit_rules

record_use_of_privileged_binaries

override_default_audit_variables
