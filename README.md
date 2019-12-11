# bosh-linux-stemcell-builder

Tools for creating stemcells.

## Building a stemcell locally

First make sure you have a local copy of this repository. Additionally, you must
download an external asset - `VMware-ovftool-*.bundle`. See **External Assets**
for instructions on where to download it from. Please place that asset in
`ci/docker` directory.

If you already have a stemcell-building environment set up and ready, skip to
the **Build Steps** section. Otherwise, follow one of these two methods before
trying to run the commands in **Build Steps**.

**If you have docker installed**,

    host$ cd ci/docker
    host$ ./run os-image-stemcell-builder

**If you are not running on Linux or you do not have Docker installed**, use
`vagrant` to start a new VM which has Docker, and then change back into the
`./docker` directory...

    host$ vagrant up
    host$ vagrant ssh

Once you have Docker running, run `./run`...

    vagrant$ cd /opt/bosh/ci/docker
    vagrant$ ./run os-image-stemcell-builder
    container$ whoami
    ubuntu

*You're now ready to continue from the **Build Steps** section.*

**Troubleshooting**: if you run into issues, try destroying any existing VM,
update your box, and try again...

    host$ vagrant destroy
    host$ vagrant box update

## Build Steps

At this point, you should be ssh'd and running within a docker container in the
`bosh-linux-stemcell-builder` directory. Start by installing the latest
dependencies before continuing to a specific build task...

    $ echo $PWD
    /opt/bosh
    $ bundle install --local


### Build an OS image

An OS image is a tarball that contains a snapshot of an entire OS filesystem
that contains all the libraries and system utilities that the BOSH agent depends
on. It does not contain the BOSH agent or the virtualization tools: there is [a
separate Rake task](#with-local-os-image) that adds the BOSH agent and a chosen
set of virtualization tools to any base OS image, thereby producing a stemcell.
The OS Image should be rebuilt when you are making changes to packages we
install in the operating system, or when making changes to how we configure
those packages, or if you need to pull in and test an updated package from
upstream.

    $ mkdir -p $PWD/tmp
    $ bundle exec rake stemcell:build_os_image[ubuntu,xenial,$PWD/tmp/ubuntu_base_image.tgz]

The arguments to `stemcell:build_os_image` are:

0. *`operating_system_name`* (`ubuntu`): identifies which type of OS to fetch.
   Determines which package repository and packaging tool will be used to
   download and assemble the files. Currently, only `ubuntu` is recognized.
0. *`operating_system_version`* (`xenial`): an identifier that the system may use
   to decide which release of the OS to download. Acceptable values depend on
   the operating system. For `ubuntu`, use `xenial`.
0. *`os_image_path`* (`$PWD/tmp/ubuntu_base_image.tgz`): the path to write the
   finished OS image tarball to. If a file exists at this path already, it will
   be overwritten without warning.


### Building a Stemcell

The stemcell should be rebuilt when you are making and testing BOSH-specific
changes on top of the base OS image such as new bosh-agent versions, or updating
security configuration, or changing user settings.

    $ mkdir -p $PWD/tmp
    $ bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,xenial,$PWD/tmp/ubuntu_base_image.tgz,"1.23"]

The arguments to `stemcell:build_with_local_os_image` are:

0. `infrastructure_name` (`aws`): Which IAAS you are producing the stemcell for.
   Determines which virtualization tools to package on top of the stemcell.
0. `hypervisor_name` (`xen`): Depending on what the IAAS supports, which
   hypervisor to target.
0. `operating_system_name` (`ubuntu`): Type of OS. Same as
   `stemcell:build_os_image`
0. `operating_system_version` (`xenial`): OS release. Same as
   `stemcell:build_os_image`
0. `os_image_path` (`$PWD/tmp/ubuntu_base_image.tgz`): Path to base OS image
   produced in `stemcell:build_os_image`
0. `build_number` (`1.23`): Stemcell version.

The final argument, which specifies the build number, is optional and will
default to '0000'


## Testing

### How to run tests for OS Images

The OS tests are meant to be run against the OS environment to which they
belong. When you run the `stemcell:build_os_image` rake task, it will create a
.raw OS image that it runs the OS specific tests against. You will need to run
the rake task the first time you create your docker container, but everytime
after, as long as you do not destroy the container, you should be able to just
run the specific tests.

To run the `ubuntu_xenial_spec.rb` tests for example you will need to:

* `bundle exec rake stemcell:build_os_image[ubuntu,xenial,$PWD/tmp/ubuntu_base_image.tgz]`
* -update tests-

Then run the following:

    cd /opt/bosh/bosh-stemcell
    OS_IMAGE=/opt/bosh/tmp/ubuntu_base_image.tgz bundle exec rspec -fd spec/os_image/ubuntu_xenial_spec.rb

### How to run tests for Stemcell

When you run the `stemcell:build_with_local_os_image` or `stemcell:build` rake
task, it will create a stemcell that it runs the stemcell specific tests
against. You will need to run the rake task the first time you create your
docker container, but everytime after, as long as you do not destroy the
container, you should be able to just run the specific tests.

To run the stemcell tests when building against local OS image you will need to:

* `bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,xenial,$PWD/tmp/ubuntu_base_image.tgz]`
* -make test changes-

Then run the following:
```sh
    $ cd /opt/bosh/bosh-stemcell; \
    STEMCELL_IMAGE=/mnt/stemcells/aws/xen/ubuntu/work/work/aws-xen-ubuntu.raw \
    STEMCELL_WORKDIR=/mnt/stemcells/aws/xen/ubuntu/work/work/chroot \
    OS_NAME=ubuntu \
    bundle exec rspec -fd --tag ~exclude_on_aws \
    spec/os_image/ubuntu_xenial_spec.rb \
    spec/stemcells/ubuntu_xenial_spec.rb \
    spec/stemcells/go_agent_spec.rb \
    spec/stemcells/aws_spec.rb \
    spec/stemcells/stig_spec.rb \
    spec/stemcells/cis_spec.rb
```

### ShelloutTypes

In pursuit of more robustly testing, we wrote our testing library for stemcell
contents, called ShelloutTypes.

The ShelloutTypes code has its own unit tests, but require root privileges and
an ubuntu chroot environment to run. For this reason, we use the
`bosh/main-ubuntu-chroot` docker imagefor unit tests. To run these unit tests
locally, run:

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

    $ bundle exec rake stemcell:build_os_image[ubuntu,xenial,$PWD/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config


## Pro Tips

* If the OS image has been built and so long as you only make test case
  modifications you can just rerun the tests (without rebuilding OS image).
  Details in section `How to run tests for OS Images`
* If the Stemcell has been built and you are only updating tests, you do not
  need to re-build the stemcell. You can simply rerun the tests (without
  rebuilding Stemcell. Details in section `How to run tests for Stemcell`
* It's possible to verify OS/Stemcell changes without making a deployment using
  the stemcell. For an AWS specific ubuntu stemcell, the filesytem is available
  at `/mnt/stemcells/aws/xen/ubuntu/work/work/chroot`

## External Assets

The ovftool installer from VMWare can be found at
[my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489).

## Rebuilding the docker image

The Docker image is published to
[`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/).
You will need the ovftool installer present on your filesystem.

Rebuild the container with the `build` script...

    vagrant$ ./build os-image-stemcell-builder

When ready, `push` to DockerHub and use the credentials from LastPass...

    vagrant$ cd os-image-stemcell-builder
    vagrant$ ./push
