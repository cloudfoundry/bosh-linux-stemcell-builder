#!/usr/bin/env bash
# @AI-Generated
# Modified with AI assistance
# Description:
# 2026-09-15: Disable and mask Ubuntu Pro client callout units - Claude Code: Claude Opus 5

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# We really want to lock these down - but we're having issues
# with both our components and users apps assuming this is writable
# Tempfile and friends - we'll punt on this for 4/12 and revisit it
# in the immediate release cycle after that.
# Lock dowon /tmp and /var/tmp - jobs should use /var/vcap/data/tmp
chmod 0770 $chroot/tmp $chroot/var/tmp

# The Ubuntu Pro client ships installed on jammy (ubuntu-minimal depends on
# ubuntu-advantage-tools, so it cannot be purged) with its units enabled. An unattached
# client still calls contracts.canonical.com every 6h. `disable` clears the target .wants
# symlinks; `mask` keeps the units off across a package reconfigure, which `disable` alone
# would not survive.
ubuntu_pro_units="ua-timer.timer ua-timer.service esm-cache.service apt-news.service ubuntu-advantage.service ua-reboot-cmds.service"
run_in_chroot $chroot "systemctl disable ${ubuntu_pro_units}"
run_in_chroot $chroot "systemctl mask ${ubuntu_pro_units}"

# apt-invoked rather than systemd-invoked, so masking alone does not stop it:
# APT::Update::Pre-Invoke starts esm-cache.service and apt-news.service
rm -f $chroot/etc/apt/apt.conf.d/20apt-esm-hook.conf

# login-invoked ESM status message
rm -f $chroot/etc/update-motd.d/91-contract-ua-esm-status
