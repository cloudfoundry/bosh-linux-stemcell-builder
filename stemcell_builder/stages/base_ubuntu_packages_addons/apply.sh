#!/usr/bin/env bash
# SPDX-FileCopyrightText: CloudFoundry.org Foundation, Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

base_dir=$(readlink -nf "$(dirname "$0")/../..")
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"
# shellcheck source=../../lib/prelude_bosh.bash
source "$base_dir/lib/prelude_bosh.bash"

# additional ubuntu packages to be installed for GDC beyond those in base_ubuntu_packages
debs_addson="cloud-init selinux-utils policycoreutils tree jq cracklib-runtime"

pkg_mgr install "$debs_addson"

# cloud-init ships /etc/rsyslog.d/21-cloudinit.conf, which routes "[CLOUDINIT]" tagged
# messages to /var/log/cloud-init.log and then stops processing ("& stop"). The stemcell spec
# "rsyslog conf directory only contains the builder-specified config files" expects only
# 34-bosh-agent.conf and 50-default.conf, so merge the cloud-init rule into 34-bosh-agent.conf
# and drop the package-provided file. It is PREPENDED to 34-bosh-agent.conf (not appended to
# 50-default.conf) so that, exactly like the original 21- file, it is evaluated before both the
# syslog-release forwarding catch-all that the syslog_forwarder job drops in as
# 35-syslog-release-forwarding-rules.conf and the "*.* /var/log/syslog" catch-all in
# 50-default.conf; otherwise cloud-init messages would be forwarded/duplicated before "& stop".
rsyslog_dir="$chroot/etc/rsyslog.d"
if [ -f "$rsyslog_dir/21-cloudinit.conf" ]; then
  cat "$rsyslog_dir/21-cloudinit.conf" "$rsyslog_dir/34-bosh-agent.conf" > "$rsyslog_dir/34-bosh-agent.conf.new"
  mv "$rsyslog_dir/34-bosh-agent.conf.new" "$rsyslog_dir/34-bosh-agent.conf"
  chmod 0644 "$rsyslog_dir/34-bosh-agent.conf"
  rm -f "$rsyslog_dir/21-cloudinit.conf"
fi

restrict_binary_setuid
