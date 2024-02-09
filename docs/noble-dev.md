# issues found
ubunty-noble/master cloned from ubuntu-jammy/master on 07-02-2024 (dd/mm/yyyy)

all todos or known issues are tagged as `noble_TODO:`

#### stemcell_builder/stages/base-ubuntu-package/apply.sh
- libpam-cracklib not availble (yet) installed in | PAM module to enable cracklib support
- rsyslog-mmjsonparse rsyslog-mmnormalize not availble as adiscon does not have a noble repo

#### stemcell_builder/stages/passowrd_policies/apply.sh
- paching common-password is failing as cracklib is not availble

#### bosh-stemcell/spec/os-image/ubuntu_noble.spec
- order changed
- gnats user/group is removed (i don't know why)
- rescan-scsi-bus does not exists anymore in noble and it seems to be a relic from the past when we used in bosh

