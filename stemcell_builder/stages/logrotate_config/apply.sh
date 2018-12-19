#!/usr/bin/env bash

set -e

base_dir="$(readlink -nf "$(dirname "$0")"/../..)"
# shellcheck source=../../lib/prelude_apply.bash
source "$base_dir/lib/prelude_apply.bash"

install_logrotate_conf() {
  # The logrotate.conf supplied by the default image is about to be stomped.
  # Make sure it hasn't changed. If it has changed, the contents of the new file should
  # evaluated to see if the replacement file should be updated.
  if [ "$(get_os_type)" == "centos" ]; then
    echo "3129afc4edd2483030c6be7e7e7e1a7bfb3f110a  $chroot/etc/logrotate.conf" | sha1sum -c
    # shellcheck disable=SC2154
    cp "$assets_dir/centos-logrotate.conf" "$chroot/etc/logrotate.conf"
  elif [ "$(get_os_type)" == "ubuntu" ]; then
    echo "7e52df7373b42a36b2bdde9bc88315e828cdc61e  $chroot/etc/logrotate.conf" | sha1sum -c
    cp "$assets_dir/ubuntu-logrotate.conf" "$chroot/etc/logrotate.conf"
  elif [ "$(get_os_type)" == "opensuse" ]; then
    echo "47755bc41e67be920d97a2ba027a2263274ed69f  $chroot/etc/logrotate.conf" | sha1sum -c
    cp "$assets_dir/opensuse-logrotate.conf" "$chroot/etc/logrotate.conf"
  fi
}

install_logrotate_cron_printer() {
  cp "${assets_dir}/print-logrotate-cron.sh" "$chroot/usr/bin/print-logrotate-cron.sh"
  chmod 755 "$chroot/usr/bin/print-logrotate-cron.sh"
}

seed_default_logrotate_cronjob() {
  "$chroot/usr/bin/print-logrotate-cron.sh" 0 > "$chroot/etc/cron.d/logrotate" # seed it with a default value
  chmod 0600 "$chroot/etc/cron.d/logrotate"
}

install_setup_logrotate_script() {
  cp "${assets_dir}/setup-logrotate.sh" "$chroot/usr/bin/setup-logrotate.sh"
  chmod 700 "$chroot/usr/bin/setup-logrotate.sh"
}

install_logrotate_cron_script() {
  mv "$chroot/etc/cron.daily/logrotate" "$chroot/usr/bin/logrotate-cron"
  sed -i -e 's/^\s*\(\/usr\/sbin\/logrotate\)\b/nice -n 19 ionice -c3 \1/' "$chroot/usr/bin/logrotate-cron"
}

install_default_su_directive() {
  cp -f "$assets_dir/default_su_directive" "$chroot/etc/logrotate.d/default_su_directive"
}

install_logrotate_conf
install_logrotate_cron_printer
seed_default_logrotate_cronjob
install_setup_logrotate_script
install_logrotate_cron_script
install_default_su_directive
