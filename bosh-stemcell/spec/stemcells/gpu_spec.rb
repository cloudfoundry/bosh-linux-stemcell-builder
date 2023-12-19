require 'spec_helper'

describe 'Ubuntu 22.04 GPU stemcell image', stemcell_image: true do

    describe 'record use of privileged programs (CIS-8.1.12)'  do
      let(:privileged_binaries) {
        command("find /bin /sbin /usr/bin /usr/sbin /boot -xdev \\( -perm -4000 -o -perm -2000 \\) -type f")
          .stdout
          .split
      }

      describe file('/etc/audit/rules.d/audit.rules') do
        its(:content) do
          privileged_binaries.each do |privileged_binary|
            should match /^-a always,exit -F path=#{privileged_binary} -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged$/
          end
        end
      end
    end

    context 'System command files must have mode 0755 or less permissive (stig: V-38469)' do
        describe command('find -L /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin -perm /022 -type f') do
          its (:stdout) { should eq('') }
        end
    end

    describe 'allowed user accounts' do
        describe file('/etc/passwd') do
          its(:content) { should eql(<<HERE) }
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:100:102:systemd Network Management,,,:/run/systemd:/usr/sbin/nologin
systemd-resolve:x:101:103:systemd Resolver,,,:/run/systemd:/usr/sbin/nologin
messagebus:x:102:105::/nonexistent:/usr/sbin/nologin
systemd-timesync:x:103:106:systemd Time Synchronization,,,:/run/systemd:/usr/sbin/nologin
syslog:x:104:111::/home/syslog:/usr/sbin/nologin
_apt:x:105:65534::/nonexistent:/usr/sbin/nologin
_chrony:x:106:112:Chrony daemon,,,:/var/lib/chrony:/usr/sbin/nologin
uuidd:x:107:114::/run/uuidd:/usr/sbin/nologin
tcpdump:x:108:115::/nonexistent:/usr/sbin/nologin
runit-log:x:999:999:Created by dh-sysuser for runit:/nonexistent:/usr/sbin/nologin
_runit-log:x:998:998:Created by dh-sysuser for runit:/nonexistent:/usr/sbin/nologin
sshd:x:109:65534::/run/sshd:/usr/sbin/nologin
vcap:x:1000:1000:BOSH System User:/home/vcap:/bin/bash
nvidia-persistenced:x:110:117:NVIDIA Persistence Daemon,,,:/nonexistent:/usr/sbin/nologin
HERE
    end
    
        describe file('/etc/shadow') do
          shadow_match = Regexp.new <<'END_SHADOW', [Regexp::MULTILINE]
\Aroot:(.+):(\d{5}):0:99999:7:::
daemon:\*:(\d{5}):0:99999:7:::
bin:\*:(\d{5}):0:99999:7:::
sys:\*:(\d{5}):0:99999:7:::
sync:\*:(\d{5}):0:99999:7:::
games:\*:(\d{5}):0:99999:7:::
man:\*:(\d{5}):0:99999:7:::
lp:\*:(\d{5}):0:99999:7:::
mail:\*:(\d{5}):0:99999:7:::
news:\*:(\d{5}):0:99999:7:::
uucp:\*:(\d{5}):0:99999:7:::
proxy:\*:(\d{5}):0:99999:7:::
www-data:\*:(\d{5}):0:99999:7:::
backup:\*:(\d{5}):0:99999:7:::
list:\*:(\d{5}):0:99999:7:::
irc:\*:(\d{5}):0:99999:7:::
gnats:\*:(\d{5}):0:99999:7:::
nobody:\*:(\d{5}):0:99999:7:::
systemd-network:\*:(\d{5}):0:99999:7:::
systemd-resolve:\*:(\d{5}):0:99999:7:::
messagebus:\*:(\d{5}):0:99999:7:::
systemd-timesync:\*:(\d{5}):0:99999:7:::
syslog:\*:(\d{5}):0:99999:7:::
_apt:\*:(\d{5}):0:99999:7:::
_chrony:\*:(\d{5}):0:99999:7:::
uuidd:\*:(\d{5}):0:99999:7:::
tcpdump:\*:(\d{5}):0:99999:7:::
runit-log:!:(\d{5})::::::
_runit-log:!:(\d{5})::::::
sshd:\*:(\d{5}):0:99999:7:::
vcap:(.+):(\d{5}):1:99999:7:::
nvidia-persistenced:(.+):(\d{5}):1:99999:7:::\Z
END_SHADOW
    
        its(:content) { should match(shadow_match) }
    end
    
    describe file('/etc/group') do
          its(:content) { should eql(<<HERE) }
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:vcap
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:vcap
fax:x:21:
voice:x:22:
cdrom:x:24:vcap
floppy:x:25:vcap
tape:x:26:
sudo:x:27:vcap
audio:x:29:vcap
dip:x:30:vcap
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
gnats:x:41:
shadow:x:42:
utmp:x:43:
video:x:44:vcap
sasl:x:45:
plugdev:x:46:vcap
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
systemd-journal:x:101:
systemd-network:x:102:
systemd-resolve:x:103:
crontab:x:104:
messagebus:x:105:
systemd-timesync:x:106:
input:x:107:
sgx:x:108:
kvm:x:109:
render:x:110:
syslog:x:111:
_chrony:x:112:
netdev:x:113:
uuidd:x:114:
tcpdump:x:115:
_ssh:x:116:
runit-log:x:999:
_runit-log:x:998:
admin:x:997:vcap
vcap:x:1000:syslog
bosh_sshers:x:1001:vcap
bosh_sudoers:x:1002:
nvidia-persistenced:x:117:
HERE
        end
    
    describe file('/etc/gshadow') do
          its(:content) { should eql(<<HERE) }
root:*::
daemon:*::
bin:*::
sys:*::
adm:*::vcap
tty:*::
disk:*::
lp:*::
mail:*::
news:*::
uucp:*::
man:*::
proxy:*::
kmem:*::
dialout:*::vcap
fax:*::
voice:*::
cdrom:*::vcap
floppy:*::vcap
tape:*::
sudo:*::vcap
audio:*::vcap
dip:*::vcap
www-data:*::
backup:*::
operator:*::
list:*::
irc:*::
src:*::
gnats:*::
shadow:*::
utmp:*::
video:*::vcap
sasl:*::
plugdev:*::vcap
staff:*::
games:*::
users:*::
nogroup:*::
systemd-journal:!::
systemd-network:!::
systemd-resolve:!::
crontab:!::
messagebus:!::
systemd-timesync:!::
input:!::
sgx:!::
kvm:!::
render:!::
syslog:!::
_chrony:!::
netdev:!::
uuidd:!::
tcpdump:!::
_ssh:!::
runit-log:!::
_runit-log:!::
admin:!::vcap
vcap:!::syslog
bosh_sshers:!::vcap
bosh_sudoers:!::
nvidia-persistenced:!::
HERE
        end
    end
end
