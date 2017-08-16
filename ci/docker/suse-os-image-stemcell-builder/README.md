## Requirements

Docker installed

## Building the docker image

To build the image with kiwi we use a docker container that brings all required dependencies.

To build that docker image first download the ovftool installer from VMWare as described in the main README.

Then run from the repository root

```bash
pushd ci/docker/suse-os-image-stemcell-builder
./build
popd
```

## Starting the environment

Start the builder container using

```bash
ci/docker/run suse-os-image-stemcell-builder
```

and install the required rubygems

```
bundle install --local
```

## Building the image

```bash
# Usually the script expects the building user to have user id 1000. The SUSE based container also supports
# other ids, though. This behaviour can be enabled by setting the `SKIP_UID_CHECK` environment variable.
export SKIP_UID_CHECK=1
mkdir -p $PWD/tmp
bundle exec rake stemcell:build_os_image[opensuse,leap,$PWD/tmp/os_leap_base_image.tgz]
```

At the end of the process you should see all image tests pass.

## Building the openSUSE openstack stemcell

Start the generation of the stemcell by running the following command:

```
export BOSH_MICRO_ENABLED=no
bundle exec rake stemcell:build_with_local_os_image[openstack,kvm,opensuse,leap,$PWD/tmp/os_leap_base_image.tgz]
```

At the end of the process the stemcell builder will run some tests. If they all pass a stemcell should exist in the `tmp` folder under your current directory.
