Current development on new stemcells.

requirements:
- [bucc](https://github.com/starkandwayne/bucc)
- [virtualbox](https://www.virtualbox.org/) 6.1 =>

## create stemcell
run container
```
cd ~/workspace/bosh-linux-stemcell-builder/ci/docker
./run os-image-stemcell-builder-impish
bundle exec rake stemcell:build_os_image[ubuntu,impish,$PWD/tmp/ubuntu_base_image.tgz]
```

## deploy a bosh director with the new stemcell on virtualbox
```
mkdir -p ~/workspace
git clone https://github.com/starkandwayne/bucc
cd bucc
mkdir operators
```
```
echo -e '
- name: stemcell
  path: /resource_pools/name=vms/stemcell?
  type: replace
  value:
    url: file://~/workspace/bosh/bosh-linux-stemcell-builder/tmp/bosh-stemcell-1.23-vsphere-esxi-ubuntu-impish-go_agent.tgz

#user = vcap
#password = c1oudc0w
- name: stemcell
  path: /resource_pools/0/env/bosh/password?
  type: replace
  value: "$6$3RO2Vvl4EXS2TMRD$IaNjbMHYCSBiQLQr0PKK8AdfDHTsNunqh3kO7USouNS/tWAvH0JmtDfrhLlHwN0XUCUrBVpQ02hoHYgTdaaeY1"
' > operators/stemcell.yml
```

run `bucc up`