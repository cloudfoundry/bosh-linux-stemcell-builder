#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

chmod 0600 $chroot/etc/ssh/sshd_config

# protect against as-shipped sshd_config that has no newline at end
echo "" >> $chroot/etc/ssh/sshd_config

sed "/^ *UseDNS/d" -i $chroot/etc/ssh/sshd_config
echo 'UseDNS no' >> $chroot/etc/ssh/sshd_config

sed "/^ *PermitRootLogin/d" -i $chroot/etc/ssh/sshd_config
echo 'PermitRootLogin no' >> $chroot/etc/ssh/sshd_config

sed "/^ *X11Forwarding/d" -i $chroot/etc/ssh/sshd_config
sed "/^ *X11DisplayOffset/d" -i $chroot/etc/ssh/sshd_config
echo 'X11Forwarding no' >> $chroot/etc/ssh/sshd_config

sed "/^ *MaxAuthTries/d" -i $chroot/etc/ssh/sshd_config
echo 'MaxAuthTries 3' >> $chroot/etc/ssh/sshd_config

sed "/^ *PermitEmptyPasswords/d" -i $chroot/etc/ssh/sshd_config
echo 'PermitEmptyPasswords no' >> $chroot/etc/ssh/sshd_config

sed "/^ *Protocol/d" -i $chroot/etc/ssh/sshd_config
echo 'Protocol 2' >> $chroot/etc/ssh/sshd_config

sed "/^ *HostbasedAuthentication/d" -i $chroot/etc/ssh/sshd_config
echo 'HostbasedAuthentication no' >> $chroot/etc/ssh/sshd_config

sed "/^ *Banner/d" -i $chroot/etc/ssh/sshd_config
echo 'Banner /etc/issue.net' >> $chroot/etc/ssh/sshd_config

sed "/^ *IgnoreRhosts/d" -i $chroot/etc/ssh/sshd_config
echo 'IgnoreRhosts yes' >> $chroot/etc/ssh/sshd_config

sed "/^ *ClientAliveInterval/d" -i $chroot/etc/ssh/sshd_config
echo 'ClientAliveInterval 300' >> $chroot/etc/ssh/sshd_config

sed "/^ *LoginGraceTime/d" -i $chroot/etc/ssh/sshd_config
echo 'LoginGraceTime 60' >> $chroot/etc/ssh/sshd_config

sed "/^ *Compression/d" -i $chroot/etc/ssh/sshd_config
echo 'Compression delayed' >> $chroot/etc/ssh/sshd_config

sed "/^ *PermitUserEnvironment/d" -i $chroot/etc/ssh/sshd_config
echo 'PermitUserEnvironment no' >> $chroot/etc/ssh/sshd_config

sed "/^ *ClientAliveCountMax/d" -i $chroot/etc/ssh/sshd_config
echo 'ClientAliveCountMax 1' >> $chroot/etc/ssh/sshd_config

sed "/^ *PasswordAuthentication/d" -i $chroot/etc/ssh/sshd_config
echo 'PasswordAuthentication no' >> $chroot/etc/ssh/sshd_config

sed "/^ *PrintLastLog/d" -i $chroot/etc/ssh/sshd_config
echo 'PrintLastLog yes' >> $chroot/etc/ssh/sshd_config

sed "/^ *AllowGroups/d" -i $chroot/etc/ssh/sshd_config
echo 'AllowGroups bosh_sshers' >> $chroot/etc/ssh/sshd_config

sed "/^ *DenyUsers/d" -i $chroot/etc/ssh/sshd_config
echo 'DenyUsers root' >> $chroot/etc/ssh/sshd_config

sed "/^[ #]*HostKey \/etc\/ssh\/ssh_host_dsa_key/d" -i $chroot/etc/ssh/sshd_config
for type in {rsa,ecdsa,ed25519}; do
  sed "s/^[ #]*HostKey \/etc\/ssh\/ssh_host_${type}_key/HostKey \/etc\/ssh\/ssh_host_${type}_key/" -i $chroot/etc/ssh/sshd_config
done

# OS Specifics
if [ "$(get_os_type)" == "centos" -o "$(get_os_type)" == "rhel" -o "$(get_os_type)" == "photonos" ]; then
  # Allow only 3DES and AES series ciphers
  sed "/^ *Ciphers/d" -i $chroot/etc/ssh/sshd_config
  echo 'Ciphers aes256-ctr,aes192-ctr,aes128-ctr' >> $chroot/etc/ssh/sshd_config

  # Disallow Weak MACs
  sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
  echo 'MACs hmac-sha2-512,hmac-sha2-256' >> $chroot/etc/ssh/sshd_config

elif [ "$(get_os_type)" == "ubuntu" ]; then
  #  Allow only 3DES and AES series ciphers
  sed "/^ *Ciphers/d" -i $chroot/etc/ssh/sshd_config
  echo 'Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr' >> $chroot/etc/ssh/sshd_config

  # Disallow Weak MACs
  sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
  echo 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com' >> $chroot/etc/ssh/sshd_config

elif [ "$(get_os_type)" == "opensuse" ]; then
  # Allow only 3DES and AES series ciphers
  sed "/^ *Ciphers/d" -i $chroot/etc/ssh/sshd_config
  echo 'Ciphers aes256-ctr,aes192-ctr,aes128-ctr' >> $chroot/etc/ssh/sshd_config

  # Disallow Weak MACs
  sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
  echo 'MACs hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,hmac-sha1' >> $chroot/etc/ssh/sshd_config

  sed "/^ *ChallengeResponseAuthentication/d" -i $chroot/etc/ssh/sshd_config
  echo 'ChallengeResponseAuthentication no' >> $chroot/etc/ssh/sshd_config

else
  echo "Unknown OS type $(get_os_type)"
  exit 1

fi

cat << EOF > $chroot/etc/issue
Unauthorized use is strictly prohibited. All access and activity
is subject to logging and monitoring.
EOF

cp $chroot/etc/issue{,.net}

touch $chroot/etc/motd

for file in $chroot/etc/{issue,issue.net,motd}; do
    chown root:root $file
    chmod 644 $file
done

# Disable Ubuntu motd (and create file if missing)
if [[ -e $chroot/etc/default/motd-news ]]
then
  sudo sed -i 's/^ENABLED=.*/ENABLED=0/' $chroot/etc/default/motd-news
else
  sudo echo "ENABLED=0" >$chroot/etc/default/motd-news
fi
