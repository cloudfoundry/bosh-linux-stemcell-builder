#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/stages/bosh_audit/shared_functions.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install audit

run_in_bosh_chroot $chroot "systemctl disable auditd.service"

write_shared_audit_rules

echo '
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/lib64/dbus-1/dbus-daemon-launch-helper -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/openssh/ssh-keysign -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/sssd/krb5_child -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/sssd/ldap_child -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/sssd/p11_child -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/sssd/proxy_child -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/sssd/selinux_child -k privileged
-a always,exit -F perm=x -F auid>=500 -F auid!=4294967295 -F path=/usr/libexec/utempter/utempter -k privileged
' >> $chroot/etc/audit/rules.d/audit.rules

# for stig V-38663: brings file permissions in aligment with what is declared by the RPM database
# this is techinically not necessary as per the stig definition, but our tests are not as lenient as the stig is
chmod 640 $chroot/etc/audit/rules.d/audit.rules

record_use_of_privileged_binaries

override_default_audit_variables
