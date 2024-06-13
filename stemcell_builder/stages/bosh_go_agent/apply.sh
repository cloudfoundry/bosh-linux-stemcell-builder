#!/usr/bin/env bash

set -e
base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Alerts for monit config
cp -a $assets_dir/alerts.monitrc $chroot/var/vcap/monit/alerts.monitrc
cd $assets_dir

wget -O /usr/bin/meta4 https://github.com/dpb587/metalink/releases/download/v0.2.0/meta4-0.2.0-linux-amd64 \
  && echo "81a592eaf647358563f296aced845ac60d9061a45b30b852d1c3f3674720fe19  /usr/bin/meta4" | shasum -a 256 -c \
  && chmod +x /usr/bin/meta4

bosh_agent_version=$(cat ${assets_dir}/bosh-agent-version)
/usr/bin/meta4 file-download --metalink=${assets_dir}/metalink.meta4 --file=bosh-agent-${bosh_agent_version}-linux-amd64 bosh-agent

mv bosh-agent $chroot/var/vcap/bosh/bin/

cp $assets_dir/bosh-agent-rc $chroot/var/vcap/bosh/bin/bosh-agent-rc

cat > $chroot/var/vcap/bosh/bin/restart_networking <<EOF
#!/bin/bash
systemctl restart systemd-networkd
EOF
chmod +x $chroot/var/vcap/bosh/bin/restart_networking

chmod +x $chroot/var/vcap/bosh/bin/bosh-agent
chmod +x $chroot/var/vcap/bosh/bin/bosh-agent-rc

# Setup additional permissions
run_in_chroot $chroot "
rm -f /etc/cron.deny
rm -f /etc/at.deny

chmod 0770 /var/lock
chown -h root:vcap /var/lock
chown -LR root:vcap /var/lock

echo 'vcap' > /etc/cron.allow
echo 'vcap' > /etc/at.allow

chmod -f og-rwx /etc/at.allow /etc/cron.allow /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d
chown -f root:root /etc/at.allow /etc/cron.allow /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d

chmod 0600 /var/vcap/monit/alerts.monitrc
chown root:root /var/vcap/monit/alerts.monitrc
"

# set symlink for bosh-agent logs so we can keep the same log locations for our tests
run_in_chroot $chroot "ln -s /var/log/bosh-agent.log /var/vcap/bosh/log/current"

# Since go agent is always specified with -C provide empty conf.
# File will be overwritten in whole by infrastructures.
echo '{}' > $chroot/var/vcap/bosh/agent.json

# this directory is utilized by the agent/init/create-env
# https://github.com/cloudfoundry/bosh-agent/blob/1a6b1e11acd941e65c4f4155c22ff9a8f76098f9/micro/https_handler.go#L119
mkdir -p $chroot/$bosh_dir/../micro_bosh/data/cache

cp "$(dirname "$0")/assets/bosh-agent.service" "${chroot}/lib/systemd/system/"
run_in_chroot "${chroot}" "systemctl enable bosh-agent.service"