# bosh-linux-stemcell-builder

Tools for creating stemcells.


## Concourse workflow

To create a stemcell on concourse instead of locally on virtualbox, you can execute the build-stemcell task.
```
mkdir /tmp/version
cat <<EOF >/tmp/version/number
0.0
EOF
cd /tmp/version
git init

pushd ~/workspace/bosh-linux-stemcell-builder
fly -t production login
IAAS=vsphere HYPERVISOR=esxi OS_NAME=ubuntu OS_VERSION=trusty time fly -t production execute -p -x -i version=/tmp/version -i bosh-linux-stemcell-builder=. -c ./ci/tasks/build.yml -o stemcell=/tmp/vsphere/dev/
popd
```

## Setup

First make sure you have a local copy of this repository. If you already have a stemcell-building environment set up and ready, skip to the **Build Steps** section. Otherwise, follow one of these two methods before trying to run the commands in **Build Steps**.

The Docker-based environment files are located in `ci/docker/os-image-stemcell-builder`...

    host$ cd ci/docker/os-image-stemcell-builder

If you are not running on Linux or you do not have Docker installed, use `vagrant` to start a new VM which has Docker, and then change back into the `./docker` directory...

    host$ vagrant up
    host$ vagrant ssh

Once you have Docker running, run `./run`...

    vagrant$ /opt/bosh/ci/docker/run os-image-stemcell-builder
    container$ whoami
    ubuntu

*You're now ready to continue from the **Build Steps** section.*

**Troubleshooting**: if you run into issues, try destroying any existing VM, update your box, and try again...

    host$ vagrant destroy
    host$ vagrant box update


## Build Steps

At this point, you should be ssh'd and running within your container in the `bosh-linux-stemcell-builder` directory. Start by installing the latest dependencies before continuing to a specific build task...

    $ echo $PWD
    /opt/bosh
    $ bundle install --local


### Build an OS image

An OS image is a tarball that contains a snapshot of an entire OS filesystem that contains all the libraries and system utilities that the BOSH agent depends on. It does not contain the BOSH agent or the virtualization tools: there is [a separate Rake task](#with-local-os-image) that adds the BOSH agent and a chosen set of virtualization tools to any base OS image, thereby producing a stemcell.

The OS Image should be rebuilt when you are making changes to which packages we install in the operating system, or when making changes to how we configure those packages, or if you need to pull in and test an updated package from upstream.

    $ mkdir -p $PWD/tmp
    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]

The arguments to `stemcell:build_os_image` are:

0. *`operating_system_name`* identifies which type of OS to fetch. Determines which package repository and packaging tool will be used to download and assemble the files. Must match a value recognized by the  [OperatingSystem](bosh-stemcell/lib/bosh/stemcell/operating_system.rb) module. Currently, `ubuntu` `centos` and `rhel` are recognized.
0. *`operating_system_version`* an identifier that the system may use to decide which release of the OS to download. Acceptable values depend on the operating system. For `ubuntu`, use `trusty`. For `centos` or `rhel`, use `7`.
0. *`os_image_path`* the path to write the finished OS image tarball to. If a file exists at this path already, it will be overwritten without warning.


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


#### Special requirements for building an openSUSE image

The openSUSE image is built using [Kiwi](http://opensuse.github.io/kiwi/) which is not available in the normal builder container. For that reason a special container has to be used. All required steps are described in the [documentation](./ci/docker/suse-os-image-stemcell-builder/README.md).

#### How to run tests for OS Images

The OS tests are meant to be run agains the OS environment to which they belong. When you run the `stemcell:build_os_image` rake task, it will create a .raw OS image that it runs the OS specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests.

To run the `centos_7_spec.rb` tests for example you will need to:

* `bundle exec rake stemcell:build_os_image[centos,7,$PWD/tmp/centos_base_image.tgz]`
* -make changes-

Then run the following:

    cd /opt/bosh/bosh-stemcell; OS_IMAGE=/opt/bosh/tmp/centos_base_image.tgz bundle exec rspec -fd spec/os_image/centos_7_spec.rb


### Building a Stemcell

The stemcell should be rebuilt when you are making and testing BOSH-specific changes on top of the base OS image such as new bosh-agent versions, or updating security configuration, or changing user settings.

#### with published OS image

The last two arguments to the rake command are the S3 bucket and key of the OS image to use (i.e. in the example below, the .tgz will be downloaded from [http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz](http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz)). More info at OS\_IMAGES.

    $ bundle exec rake stemcell:build[aws,xen,ubuntu,trusty,bosh-os-images,bosh-ubuntu-trusty-os-image.tgz,"1234.56"]

The final argument, which specifies the build number, is optional and will default to '0000'

#### with local OS image

If you want to use an OS Image that you just created, use the `stemcell:build_with_local_os_image` task, specifying the OS image tarball.

    $ bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz,"1234.56"]

The final argument, which specifies the build number, is optional and will default to '0000'

You can also download OS Images from the public S3 bucket. Public OS images can be obtained here:

* latest Ubuntu - https://s3.amazonaws.com/bosh-os-images/bosh-ubuntu-trusty-os-image.tgz
* latest CentOS - https://s3.amazonaws.com/bosh-os-images/bosh-centos-7-os-image.tgz

*Note*: you may need to append `?versionId=value` to those tarballs. You can find the expected `versionId` by looking at [`os_image_versions.json`](./os_image_versions.json).

#### How to run tests for Stemcell
When you run the `stemcell:build_with_local_os_image` or `stemcell:build` rake task, it will create a stemcell that it runs the stemcell specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests.

To run the stemcell tests when building against local OS image you will need to:

* `bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]`
* -make test changes-

Then run the following:
```sh
    $ cd /opt/bosh/bosh-stemcell; \
    STEMCELL_IMAGE=/mnt/stemcells/aws/xen/ubuntu/work/work/aws-xen-ubuntu.raw \
    STEMCELL_WORKDIR=/mnt/stemcells/aws/xen/ubuntu/work/work/chroot \
    OS_NAME=ubuntu \
    bundle exec rspec -fd --tag ~exclude_on_aws \
    spec/os_image/ubuntu_trusty_spec.rb \
    spec/stemcells/ubuntu_trusty_spec.rb \
    spec/stemcells/go_agent_spec.rb \
    spec/stemcells/aws_spec.rb \
    spec/stemcells/stig_spec.rb \
    spec/stemcells/cis_spec.rb
```

## ShelloutTypes

In pursuit of more robustly testing, we wrote our testing library for stemcell contents, called ShelloutTypes.

The ShelloutTypes code has its own unit tests, but require root privileges and an ubuntu chroot environment to run. For this reason, we use the `bosh/main-ubuntu-chroot` docker imagefor unit tests. To run these unit tests locally, run:

```
$ docker run bosh/main-ubuntu-chroot    # now in /opt/bosh
$ source /etc/profile.d/chruby.sh
$ chruby 2.3.1

$ #create user for ShelloutTypes::File tests
$ chroot /tmp/ubuntu-chroot /bin/bash -c 'useradd -G nogroup shellout'

$ bundle install --local
$ cd bosh-stemcell
$ bundle exec rspec spec/ --tag shellout_types

```

The above strategy is derived from our CI unit testing job's script.

## Troubleshooting

If you find yourself debugging any of the above processes, here is what you need to know:

0. Most of the action happens in Bash scripts, which are referred to as _stages_, and can be found in `stemcell_builder/stages/<stage_name>/apply.sh`.
0. You should make all changes on your local machine, and sync them over to the AWS stemcell building machine using `vagrant provision remote` as explained earlier on this page.
0. While debugging a particular stage that is failing, you can resume the process from that stage by adding `resume_from=<stage_name>` to the end of your `bundle exec rake` command. When a stage's `apply.sh` fails, you should see a message of the form `Can't find stage '<stage>' to resume from. Aborting.` so you know which stage failed and where you can resume from after fixing the problem.

For example:

    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config


## Pro Tips

* If the OS image has been built and so long as you only make test case modifications you can just rerun the tests (without rebuilding OS image). Details in section `How to run tests for OS Images`

* If the Stemcell has been built and so long as you only make test case modifications you can rerun the tests (without rebuilding Stemcell. Details in section `How to run tests for Stemcell`

* It's possible to verify OS/Stemcell changes without making adeployment using the stemcell. For an AWS specific ubuntu stemcell, the filesytem is available at `/mnt/stemcells/aws/xen/ubuntu/work/work/chroot`


## Rebuilding the Image

The Docker image is published to [`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/).

If you need to rebuild the image, first download the ovftool installer from VMWare. Details about this can be found at [my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489). Specifically...

0. Download the `*.bundle` file to the docker image directory (`ci/docker/os-image-stemcell-builder`)
0. When upgrading versions, update `Dockerfile` with the new file path and SHA

Rebuild the container with the `build` script...

    vagrant$ ./build os-image-stemcell-builder

When ready, `push` to DockerHub and use the credentials from LastPass...

    vagrant$ cd os-image-stemcell-builder
    vagrant$ ./push
