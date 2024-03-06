# issues found
ubunty-noble/master cloned from ubuntu-jammy/master on 07-02-2024 (dd/mm/yyyy)

all todos or known issues are tagged as `noble_TODO:`

#### stemcell_builder/stages/base-ubuntu-package/apply.sh
- libpam-cracklib not availble (yet) installed in | PAM module to enable cracklib support
FIXED: with changing to libpam-pwquality
- rsyslog-mmjsonparse rsyslog-mmnormalize not availble as adiscon does not have a noble repo

#### stemcell_builder/stages/passowrd_policies/apply.sh
- paching common-password is failing as cracklib is not availble

#### bosh-stemcell/spec/os-image/ubuntu_noble.spec
- order changed
- gnats user/group is removed (i don't know why)
- rescan-scsi-bus does not exists anymore in noble and it seems to be a relic from the past when we used in bosh

#### src/ipv4director/autitd/smoke_test.go
behaviour changed on auditd it now exits 1 if error with `sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`

resolvconf package is not availble anymore and is probably not going to be backported
systemd-resolve is installed now by default
the agent forces a symlink see https://github.com/cloudfoundry/bosh-agent/blob/main/platform/net/ubuntu_net_manager.go#L477
this should not happen. also we need to change how we update resolv.conf as
nameserver=1.1.1.1 nameserver=8.8.8.8 is now DNS=1.1.1.1,8.8.8.8