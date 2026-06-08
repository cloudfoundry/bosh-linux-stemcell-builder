#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/stages/bosh_audit/shared_functions.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install auditd

run_in_bosh_chroot $chroot "systemctl disable auditd.service"
run_in_bosh_chroot $chroot "chown root:root /var/log/audit" # (stig: V-38663) (stig: V-38664) (stig: V-38665)

write_shared_audit_rules

record_use_of_privileged_binaries

override_default_audit_variables
