# BOSH Linux Stemcell Builder

This repo contains tools for creating BOSH stemcells. A stemcell is a bootable
disk image that is used as a template by a BOSH Director to create VMs.

## Quick Start: Building a Stemcell Locally

```bash
git clone git@github.com:cloudfoundry/bosh-linux-stemcell-builder.git
git checkout ubuntu-jammy/master
mkdir -p tmp
docker build \
   --tag os-image-stemcell-builder-jammy \
   $PWD/ci/docker/os-image-stemcell-builder-jammy
docker run \
   --privileged \
   -v "$(pwd):/opt/bosh" \
   --workdir /opt/bosh \
   --user=1000:1000 \
   -it \
   os-image-stemcell-builder-jammy
# You're now in the the Docker container
gem install bundler
bundle
 # build OS image
bundle exec rake stemcell:build_os_image[ubuntu,jammy,$PWD/tmp/ubuntu_base_image.tgz] # build OS image
 # build vSphere stemcell
bundle exec rake stemcell:build_with_local_os_image[vsphere,esxi,ubuntu,jammy,$PWD/tmp/ubuntu_base_image.tgz,"0.0.8"]
```

When building a vSphere stemcell, you must download `VMware-ovftool-*.bundle`
and place it in the `ci/docker` directory. See [External
Assets](#external-assets) for download instructions.

### OS image

An OS image is a tarball that contains a snapshot of an OS filesystem,
including the libraries and system utilities needed by the BOSH agent; however,
it does not contain the BOSH agent nor the virtualization tools: [a subsequent
Rake task](#with-local-os-image) adds the BOSH agent and a set of
virtualization tools to the base OS image to produce a stemcell.

The OS Image should be rebuilt when you are making changes to the packages
installed in the operating system or when making changes to the configuration
of those packages.

```bash
bundle exec rake stemcell:build_os_image[ubuntu,jammy,$PWD/tmp/ubuntu_base_image.tgz]
```

The arguments to the `stemcell:build_os_image` rake task follow:

0. *`operating_system_name`* (`ubuntu`): identifies which type of OS to fetch.
   Determines which package repository and packaging tool will be used to
   download and assemble the files.
   Currently, `ubuntu`, `centos` and `rhel` are recognized.
0. *`operating_system_version`* (`jammy`): an identifier that the system may use
   to decide which release of the OS to download. Acceptable values depend on
   the operating system.
   For `ubuntu`, use `jammy`.
   For `centos` or `rhel`, use `8` or `7`.
0. *`os_image_path`* (`$PWD/tmp/ubuntu_base_image.tgz`): the path to write the
   finished OS image tarball to. If a file exists at this path already, it will
   be overwritten without warning.

#### Special requirements for building a RHEL OS image

There are a few extra steps you need to do before building a RHEL OS image:

0. Start up or re-provision the stemcell building machine (run `vagrant up` or `vagrant provision` from this directory)
0. Download the [RHEL 7.0 Binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.0/x86_64/product-downloads) image and use `scp` to copy it to the stemcell building machine. Note that RHEL 7.1 does not yet build correctly.
0. On the stemcell building machine, mount the RHEL 7 DVD at `/mnt/rhel`:

        $ mkdir -p /mnt/rhel
        $ mount rhel-server-7.0-x86_64-dvd.iso /mnt/rhel

0. On the stemcell building machine, put your Red Hat Account username and password into environment variables:

        $ export RHN_USERNAME=my-rh-username@company.com
        $ export RHN_PASSWORD=my-password

0. On the stemcell building machine, run the stemcell building rake task:

        $ bundle exec rake stemcell:build_os_image[rhel,7,$PWD/tmp/rhel_7_base_image.tgz]

See below [Building the stemcell with local OS image](#with-local-os-image) on how to build stemcell with the new OS image.


#### Special requirements for building a PhotonOS image

There are a few extra steps you need to do before building a PhotonOS image:

0. Start up or re-provision the stemcell building machine (run `vagrant up` or `vagrant provision` from this directory)
0. Download the [latest PhotonOS ISO image](https://vmware.bintray.com/photon/iso/) and use `scp` to copy it to the stemcell building machine. The version must be TP2-dev or newer.
0. On the stemcell building machine, mount the PhotonOS ISO at `/mnt/photonos`:

        $ mkdir -p /mnt/photonos
        $ mount photon.iso /mnt/photonos

0. On the stemcell building machine, run the stemcell building rake task:

        $ bundle exec rake stemcell:build_os_image[photonos,TP2,$PWD/tmp/photon_TP2_base_image.tgz]

See below [Building the stemcell with local OS image](#with-local-os-image) on how to build stemcell with the new OS image.


#### How to run tests for OS Images

The OS tests are meant to be run agains the OS environment to which they belong. When you run the `stemcell:build_os_image` rake task, it will create a .raw OS image that it runs the OS specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests.

To run the `centos_7_spec.rb` tests for example you will need to:

* `bundle exec rake stemcell:build_os_image[centos,7,$PWD/tmp/centos_base_image.tgz]`
* -make changes-

Then run the following:

    cd /opt/bosh/bosh-stemcell; OS_IMAGE=/opt/bosh/tmp/centos_base_image.tgz bundle exec rspec -fd spec/os_image/centos_7_spec.rb


### Building a Stemcell

Rebuild the stemcell when you are making and testing BOSH-specific
changes such as a new BOSH agent.

```bash
bundle exec rake stemcell:build_with_local_os_image[vsphere,esxi,ubuntu,jammy,$PWD/tmp/ubuntu_base_image.tgz,"0.0.8"]
```

The arguments to `stemcell:build_with_local_os_image` are:

0. `infrastructure_name`: Which IaaS you are producing the stemcell for.
   Determines which virtualization tools to package on top of the stemcell.
0. `hypervisor_name`: Depending on what the IAAS supports, which hypervisor to
   target: `aws` → `xen`, `azure` → `hyperv`, `google` → `kvm`, `openstack` →
   `kvm`, `vsphere` → `esxi`
0. `operating_system_name` (`ubuntu`): Type of OS. Same as
   `stemcell:build_os_image`
0. `operating_system_version` (`jammy`): OS release. Same as
   `stemcell:build_os_image`
0. `os_image_path` (`$PWD/tmp/ubuntu_base_image.tgz`): Path to base OS image
   produced in `stemcell:build_os_image`
0. `build_number` (`0.0.8`): Stemcell version. Pro-tip: take the version number
   of the most recent release and add one, e.g.: "0.0.7" → "0.0.8". If not
   specified, it will default to "0000".

### The Resulting Stemcell

You can find the resulting stemcell in the `tmp/` directory of the host, or in
the `/opt/bosh/tmp` directory in the Docker container. Using the above example,
the stemcell would be at
`tmp/bosh-stemcell-0.0.8-vsphere-esxi-ubuntu-jammy-go_agent.tgz`. You can
upload the stemcell to a vSphere BOSH Director:

```bash
bosh upload-stemcell tmp/bosh-stemcell-0.0.8-vsphere-esxi-ubuntu-jammy-go_agent.tgz
```

## Testing

_[Fixme: update Testing section to Jammy]_

### How to run tests for OS Images

The OS tests are meant to be run against the OS environment to which they
belong. When you run the `stemcell:build_os_image` rake task, it will create a
.raw OS image that it runs the OS specific tests against. You will need to run
the rake task the first time you create your docker container, but everytime
after, as long as you do not destroy the container, you should be able to run
the specific tests.

To run the `ubuntu_jammy_spec.rb` tests (**assuming you've already built the OS
image** at the `tmp/ubuntu_base_image.tgz` and you're within the Docker
container):

    cd /opt/bosh/bosh-stemcell
    OS_IMAGE=/opt/bosh/tmp/ubuntu_base_image.tgz bundle exec rspec -fd spec/os_image/ubuntu_jammy_spec.rb

### How to Run Tests for Stemcell

When you run the `stemcell:build_with_local_os_image` or `stemcell:build` rake
task, it will create a stemcell that it runs the stemcell specific tests
against. You will need to run the **rake task the first time you create your
docker container**, but everytime after, as long as you do not destroy the
container, you should be able to run the specific tests:

```shell
cd /opt/bosh/bosh-stemcell; \
STEMCELL_IMAGE=/mnt/stemcells/vsphere/esxi/ubuntu/work/work/vsphere-esxi-ubuntu.raw \
STEMCELL_WORKDIR=/mnt/stemcells/vsphere/esxi/ubuntu/work/work/chroot \
OS_NAME=ubuntu \
bundle exec rspec -fd --tag ~exclude_on_vsphere \
spec/os_image/ubuntu_jammy_spec.rb \
spec/stemcells/ubuntu_jammy_spec.rb \
spec/stemcells/go_agent_spec.rb \
spec/stemcells/vsphere_spec.rb \
spec/stemcells/stig_spec.rb \
spec/stemcells/cis_spec.rb
```

### How to run tests for ShelloutTypes

In pursuit of more robustly testing, we wrote our testing library for stemcell
contents, called ShelloutTypes.

The ShelloutTypes code has its own unit tests, but require root privileges and
an ubuntu chroot environment to run. For this reason, we use the
`bosh/main-ubuntu-chroot` docker image for unit tests. To run these unit tests
locally, run:

```shell
bundle install --local
cd /opt/bosh/bosh-stemcell
OS_IMAGE=/opt/bosh/tmp/ubuntu_base_image.tgz bundle exec rspec spec/ --tag shellout_types
```
If on macOS, run:

```shell
OSX=true OS_IMAGE=/opt/bosh/tmp/ubuntu_base_image.tgz bundle exec rspec spec/ --tag shellout_types
```

### How to run tests for BOSH Linux Stemcell Builder

The BOSH Linux Stemcell Builder code itself can be tested with the following command's:

```shell
bundle install --local
cd /opt/bosh/bosh-stemcell
bundle exec rspec spec/
```

## Troubleshooting

If you find yourself debugging any of the above processes, here is what you need to know:

0. Most of the action happens in Bash scripts, which are referred to as
   _stages_, and can be found in
   `stemcell_builder/stages/<stage_name>/apply.sh`.
0. While debugging a particular stage that is failing, you can resume the
   process from that stage by adding `resume_from=<stage_name>` to the end of
   your `bundle exec rake` command. When a stage's `apply.sh` fails, you should
   see a message of the form `Can't find stage '<stage>' to resume from.
   Aborting.` so you know which stage failed and where you can resume from after
   fixing the problem. Please use caution as stages are not guaranteed to be
   idempotent.

   Example usage:

   ```shell
   bundle exec rake stemcell:build_os_image[ubuntu,jammy,$PWD/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config
   ```

## Pro Tips

* If the OS image has been built and so long as you only make test case
  modifications you can rerun the tests (without rebuilding OS image). Details
  in section `How to run tests for OS Images`
* If the Stemcell has been built and you are only updating tests, you do not
  need to re-build the stemcell. You can simply rerun the tests (without
  rebuilding Stemcell. Details in section `How to run tests for Stemcell`
* It's possible to verify OS/Stemcell changes without making a deployment using
  the stemcell. For a vSphere-specific Ubuntu stemcell, the filesytem is
  available at `/mnt/stemcells/vsphere/esxi/ubuntu/work/work/chroot`

## External Assets

The ovftool installer from VMWare can be found at
[my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489).

The ovftool installer must be copied into the [ci/docker/os-image-stemcell-builder-jammy](https://github.com/cloudfoundry/bosh-linux-stemcell-builder/tree/master/ci/docker/os-image-stemcell-builder) next to the Dockerfile or you will receive the error

    Step 24/30 : ADD ${OVF_TOOL_INSTALLER} /tmp/ovftool_installer.bundle
    ADD failed: stat /var/lib/docker/tmp/docker-builder389354746/VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle: no such file or directory

## Rebuilding the Docker Image

The Docker image is published to
[`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/).
You will need the ovftool installer present on your filesystem.

Rebuild the container with the `build` script...

    ./build os-image-stemcell-builder

When ready, `push` to DockerHub and use the credentials from LastPass...

    cd os-image-stemcell-builder
    ./push
