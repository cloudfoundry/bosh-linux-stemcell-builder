permit_monit_access() {
  local vcap_uid
  vcap_uid="$(id -u vcap)"

  if ! /var/vcap/bosh/etc/bosh-enable-monit-access "$vcap_uid" 2>/dev/null; then
    if nft list chain inet bosh_agent monit_access_jobs &>/dev/null; then
      if ! nft list chain inet bosh_agent monit_access_jobs 2>/dev/null | grep -q "skuid $vcap_uid"; then
        nft add rule inet bosh_agent monit_access_jobs \
          meta skuid "$vcap_uid" ip daddr 127.0.0.1 tcp dport 2822 accept
      fi
    fi
  fi
}