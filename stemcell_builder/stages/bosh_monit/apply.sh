#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash
source $base_dir/lib/iptables_common_definitions.bash

monit_basename=monit-5.2.5
monit_archive=$monit_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$monit_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $monit_archive
cd $monit_basename
./configure --prefix=$bosh_dir --without-ssl
make -j4 && make install
"

mkdir -p $chroot/$bosh_dir/etc
cp $dir/assets/monitrc $chroot/$bosh_dir/etc/monitrc
chmod 0700 $chroot/$bosh_dir/etc/monitrc

# monit refuses to start without an include file present
mkdir -p $chroot/$bosh_app_dir/monit
touch $chroot/$bosh_app_dir/monit/empty.monitrc

mv $chroot/$bosh_dir/bin/monit $chroot/$bosh_dir/bin/monit-actual
# Monit wrapper script:

cat > $chroot/$bosh_dir/bin/monit <<EOF
#/bin/bash

set -e
EOF

echo $'net_cls_location="$(cat /proc/self/mounts | grep ^cgroup | grep net_cls | awk \'{ print $2 }\' )"' >> $chroot/$bosh_dir/bin/monit

cat >> $chroot/$bosh_dir/bin/monit <<EOF
mkdir "\$net_cls_location"/monit-api-access || true
echo $monit_isolation_classid > "\$net_cls_location"/monit-api-access/net_cls.classid
EOF

cat >> $chroot/$bosh_dir/bin/monit <<'EOF'
echo $$ > "\$net_cls_location"/monit-api-access/tasks
exec monit-actual $@
EOF

chmod +x $chroot/$bosh_dir/bin/monit


cat > $chroot/etc/network/if-up.d/restrict-monit-api-access <<EOF
#!/bin/bash

if iptables -t mangle -C POSTROUTING -d 127.0.0.1 -p tcp --dport 2822 -m cgroup \! --cgroup $monit_isolation_classid -j DROP
then
  /bin/true
else
  iptables -t mangle -I POSTROUTING -d 127.0.0.1 -p tcp --dport 2822 -m cgroup \! --cgroup $monit_isolation_classid -j DROP
fi
EOF

chmod +x $chroot/etc/network/if-up.d/restrict-monit-api-access