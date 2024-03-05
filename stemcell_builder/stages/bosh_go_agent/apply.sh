#!/usr/bin/env bash

set -e
base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/etc/sv
cp -a $assets_dir/runit/agent $chroot/etc/sv/agent
cp -a $assets_dir/runit/monit $chroot/etc/sv/monit
mkdir -p $chroot/var/vcap/monit/svlog

# Set up agent and monit with runit
run_in_bosh_chroot $chroot "
rm /etc/service
mkdir /etc/service
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
rm -f /etc/service/agent
ln -s /etc/sv/agent /etc/service/agent

chmod +x /etc/sv/monit/run /etc/sv/monit/log/run
rm -f /etc/service/monit
ln -s /etc/sv/monit /etc/service/monit
"

# Alerts for monit config
cp -a $assets_dir/alerts.monitrc $chroot/var/vcap/monit/alerts.monitrc
cd $assets_dir

# wget -O /usr/bin/meta4 https://github.com/dpb587/metalink/releases/download/v0.2.0/meta4-0.2.0-linux-amd64 \
#   && echo "81a592eaf647358563f296aced845ac60d9061a45b30b852d1c3f3674720fe19  /usr/bin/meta4" | shasum -a 256 -c \
#   && chmod +x /usr/bin/meta4

# bosh_agent_version=$(cat ${assets_dir}/bosh-agent-version)
# /usr/bin/meta4 file-download --metalink=${assets_dir}/metalink.meta4 --file=bosh-agent-${bosh_agent_version}-linux-amd64 bosh-agent

# mv bosh-agent $chroot/var/vcap/bosh/bin/

#TODO: uncomment above and remove the line below once we have a the bosha-agent is fixed upstream to use systemd-resolve
mv $assets_dir/bosh-agent $chroot/var/vcap/bosh/bin/bosh-agent

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

chmod -R 0700 /etc/sv/agent
chown -R root:root /etc/sv/agent

# monit processes will inherit this directory as the default $PWD, so make sure processes can read/list
# some scripts/packages might do this during startup and would potentially fail
chmod -R 0755 /etc/sv/monit
chown -R root:root /etc/sv/monit

chmod 0600 /var/vcap/monit/alerts.monitrc
chown root:root /var/vcap/monit/alerts.monitrc
"

# Since go agent is always specified with -C provide empty conf.
# File will be overwritten in whole by infrastructures.
echo '{}' > $chroot/var/vcap/bosh/agent.json

# this directory is utilized by the agent/init/create-env
# https://github.com/cloudfoundry/bosh-agent/blob/1a6b1e11acd941e65c4f4155c22ff9a8f76098f9/micro/https_handler.go#L119
mkdir -p $chroot/$bosh_dir/../micro_bosh/data/cache
