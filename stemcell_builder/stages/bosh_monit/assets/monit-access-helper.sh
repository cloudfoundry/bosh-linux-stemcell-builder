permit_monit_access() {
  if [ "$(id -u)" -eq 0 ]; then
    sudo -u vcap /var/vcap/bosh/etc/bosh-enable-monit-access
  else
    /var/vcap/bosh/etc/bosh-enable-monit-access
  fi
}