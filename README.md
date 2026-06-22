# BOSH Linux Stemcell Builder

This repo contains tools for creating BOSH stemcells. A stemcell is a bootable
disk image that is used as a template by a BOSH Director to create VMs.

## Quick Start: Building a Stemcell Locally

```bash
export short_name="noble"

git clone git@github.com:cloudfoundry/bosh-linux-stemcell-builder.git
cd bosh-linux-stemcell-builder
git checkout ubuntu-${short_name}
mkdir -p tmp
docker build \
   --platform linux/amd64 \
   --build-arg SYFT_VERSION=v1.42.3 \
   -t bosh/os-image-stemcell-builder:${short_name} \
   ci/docker/os-image-stemcell-builder/
docker run \
   --platform linux/amd64 \
   --privileged \
   -v "$(pwd):/opt/bosh" \
   --workdir /opt/bosh \
   --user=1000:1000 \
   -it \
   bosh/os-image-stemcell-builder:${short_name}

# You're now in the Docker container
ulimit -n 16384 # only necessary if your host is Fedora
gem install bundler
bundle install

 # build OS image
bundle exec rake stemcell:build_os_image[ubuntu,${short_name},${PWD}/tmp/ubuntu_base_image.tgz]

 # build vSphere stemcell
bundle exec rake stemcell:build[vsphere,esxi,ubuntu,${short_name},${PWD}/tmp/ubuntu_base_image.tgz]
```

When building a vSphere stemcell, you must download `VMware-ovftool-*.bundle`
and place it in the `ci/docker/os-image-stemcell-builder/` directory before
running `docker build`. See [External Assets](#external-assets) for download
instructions.

### OS image

An OS image is a tarball that contains a snapshot of an OS filesystem,
including the libraries and system utilities needed by the BOSH agent; however,
it does not contain the BOSH agent nor the virtualization tools: [a subsequent
Rake task](#building-a-Stemcell) adds the BOSH agent and a set of
virtualization tools to the base OS image to produce a stemcell.

The OS Image should be rebuilt when you are making changes to the packages
installed in the operating system or when making changes to the configuration
of those packages.

```bash
export short_name="noble"

bundle exec rake stemcell:build_os_image[ubuntu,${short_name},${PWD}/tmp/ubuntu_base_image.tgz]
```

The arguments to the `stemcell:build_os_image` rake task follow:

1. `operating_system_name` (`ubuntu`): identifies which type of OS to fetch.
   Determines which package repository and packaging tool will be used to
   download and assemble the files. Currently, only `ubuntu` is recognized.
2. `operating_system_version` (`<short_name>`): an identifier that the system may use
   to decide which release of the OS to download. Acceptable values depend on
   the operating system. For `ubuntu`, use `<short_name>`.
3. `os_image_path` (`${PWD}/tmp/ubuntu_base_image.tgz`): the path to write the
   finished OS image tarball to. If a file exists at this path already, it will
   be overwritten without warning.

### Building a Stemcell

Rebuild the stemcell when you are making and testing BOSH-specific changes such as a new BOSH agent.

```bash
export short_name="noble"
export build_number="0.0.8"

bundle exec rake stemcell:build[vsphere,esxi,ubuntu,${short_name},${PWD}/tmp/ubuntu_base_image.tgz,${build_number}]
```

The arguments to `stemcell:build` are:

1. `infrastructure_name`: Which IaaS you are producing the stemcell for.
   Determines which virtualization tools to package on top of the stemcell.
2. `hypervisor_name`: Depending on what the IAAS supports, which hypervisor to
   target:
    - `aws` → `xen-hvm`
    - `azure` → `hyperv`
    - `google` → `kvm`
    - `openstack` → `kvm`
    - `vsphere` → `esxi`
3. `operating_system_name` (`ubuntu`): Type of OS. Same as
   `stemcell:build_os_image`.
4. `operating_system_version` (`<short_name>`): OS release. Same as
   `stemcell:build_os_image`. Can optionally include a variant suffix (`<short_name>-fips`)
5. `os_image_path` (`${PWD}/tmp/ubuntu_base_image.tgz`): Path to base OS image
   produced in `stemcell:build_os_image`
6. `build_number` (`0.0.8`): Stemcell version. Pro-tip: take the version number
   of the most recent release and add one, e.g.: "0.0.7" → "0.0.8". If not
   specified, it will default to "0000".

### The Resulting Stemcell

You can find the resulting stemcell in the `tmp/` directory of the host, or in
the `/opt/bosh/tmp` directory in the Docker container. Using the above example,
the stemcell would be at
`tmp/bosh-stemcell-0.0.8-vsphere-esxi-ubuntu-<short_name>-go_agent.tgz`. You can
upload the stemcell to a vSphere BOSH Director:

```bash
export short_name="noble"

bosh upload-stemcell tmp/bosh-stemcell-0.0.8-vsphere-esxi-ubuntu-${short_name}-go_agent.tgz
```

## Testing

### How to run tests for OS Images

The OS tests are meant to be run against the OS environment to which they
belong. When you run the `stemcell:build_os_image` rake task, it will create a
.raw OS image that it runs the OS specific tests against. You will need to run
the rake task the first time you create your docker container, but everytime
after, as long as you do not destroy the container, you should be able to run
the specific tests.

To run the OS image tests in `spec/os_image/ubuntu_spec.rb` (**assuming you've already built
the OS image** at the `tmp/ubuntu_base_image.tgz` and you're within the Docker
container):

```shell
  export short_name="noble"
  cd /opt/bosh/bosh-stemcell
  bundle install
  OS_IMAGE=/opt/bosh/tmp/ubuntu_base_image.tgz bundle exec rspec -fd spec/os_image/ubuntu_spec.rb
```

### How to Run Tests for Stemcell

When you run the `stemcell:build` rake task, it will create a stemcell that it
runs the stemcell-specific tests against. You will need to run the **rake task
the first time you create your docker container**, but every time after, as
long as you do not destroy the container, you should be able to run the
specific tests:

```shell
cd /opt/bosh/bosh-stemcell; \
bundle install; \
STEMCELL_IMAGE=/mnt/stemcells/vsphere/esxi/ubuntu/work/work/vsphere-esxi-ubuntu.raw \
STEMCELL_WORKDIR=/mnt/stemcells/vsphere/esxi/ubuntu/work/work/chroot \
OS_NAME=ubuntu \
bundle exec rspec -fd --tag ~exclude_on_vsphere \
spec/os_image/ubuntu_spec.rb \
spec/stemcells/ubuntu_spec.rb \
spec/stemcells/go_agent_spec.rb \
spec/stemcells/vsphere_spec.rb \
spec/stemcells/stig_spec.rb \
spec/stemcells/cis_spec.rb
```

### How to run tests for `ShelloutTypes`

In pursuit of more robustly testing, we wrote our testing library for stemcell
contents, called `ShelloutTypes`.

The `ShelloutTypes` code has its own unit tests, but require root privileges and
an ubuntu chroot environment to run. For this reason, we use the
`bosh/main-ubuntu-chroot` docker image for unit tests. To run these unit tests
locally, run:

```shell
cd /opt/bosh/bosh-stemcell
bundle install
OS_IMAGE=/opt/bosh/tmp/ubuntu_base_image.tgz bundle exec rake spec:shellout_types
```

### How to run tests for BOSH Linux Stemcell Builder

The BOSH Linux Stemcell Builder code itself can be tested with the following command's:

```shell
cd /opt/bosh/bosh-stemcell
bundle install
bundle exec rake
```

## Troubleshooting

If you find yourself debugging any of the above processes, here is what you need to know:

1. Most of the action happens in Bash scripts, which are referred to as
   _stages_, and can be found in
   `stemcell_builder/stages/<stage_name>/apply.sh`.
2. While debugging a particular stage that is failing, you can resume the
   process from that stage by adding `resume_from=<stage_name>` to the end of
   your `bundle exec rake` command. When a stage's `apply.sh` fails, you should
   see a message of the form `Can't find stage '<stage>' to resume from.
   Aborting.` so you know which stage failed and where you can resume from after
   fixing the problem. Please use caution as stages are not guaranteed to be
   idempotent.

   Example usage:

   ```shell
   export short_name="noble"
   
   bundle exec rake stemcell:build_os_image[ubuntu,${short_name},${PWD}/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config
   ```

## Pro Tips

* If the OS image has been built and so long as you only make test case
  modifications you can rerun the tests (without rebuilding OS image). Details
  in section `How to run tests for OS Images`
* If the Stemcell has been built, and you are only updating tests, you do not
  need to re-build the stemcell. You can simply rerun the tests - without
  rebuilding Stemcell. Details in section `How to run tests for Stemcell`
* It's possible to verify OS/Stemcell changes without making a deployment using
  the stemcell. For a vSphere-specific Ubuntu stemcell, the filesystem is
  available at `/mnt/stemcells/vsphere/esxi/ubuntu/work/work/chroot`

## External Assets

The installer for `ovftool` can be found at:
- https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest.

The `ovftool` installer **for linux** must be copied into 
[os-image-stemcell-builder](ci/docker/os-image-stemcell-builder)
next to the `Dockerfile` before building the Docker image. If not you will
see an error similar to: 

```shell
ADD failed: failed to compute cache key: "/VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle": not found
```

## Rebuilding the Docker Image

The Docker image is published to
[`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/).
You will need the ovftool installer present in
`ci/docker/os-image-stemcell-builder/`.

Rebuild the container with:

```shell
export short_name="noble"

docker build \
    --platform linux/amd64 \
    --build-arg BASE_IMAGE="ubuntu:${short_name}" \
    --build-arg META4_CLI_URL="https://github.com/dpb587/metalink/releases/download/v0.5.0/meta4-0.5.0-linux-amd64" \
    --build-arg SYFT_CLI_URL="https://github.com/anchore/syft/releases/download/v1.42.3/syft_1.42.3_linux_amd64.tar.gz" \
    --build-arg YQ_CLI_URL="https://github.com/mikefarah/yq/releases/download/v4.52.5/yq_linux_amd64" \
    --build-arg RUBY_INSTALL_URL="https://github.com/postmodern/ruby-install/releases/download/v0.10.2/ruby-install-0.10.2.tar.gz" \
    --build-arg RUBY_VERSION="$(cat .ruby-version)" \
    --build-arg GEM_HOME="/usr/local/bundle" \
    --build-arg OVF_TOOL_INSTALLER="VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle" \
    --build-arg OVF_TOOL_INSTALLER_SHA1="6c24e473be49c961cfc3bb16774b52b48e822991" \
    -t bosh/os-image-stemcell-builder:${short_name} \
    ci/docker/os-image-stemcell-builder/
```

## CI Infrastructure

### Docker Images and VMware ovftool

When creating a new LTS stemcell you will need to create a folder and upload
the appropriate ovftool to the GCP bucket `bosh-vmware-ovftool`:

```shell
gsutil cp MY_OVFTOOL_FILE gs://bosh-vmware-ovftool/MY_OS/
```

Example:

```shell
export short_name="noble"

gsutil cp VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle gs://bosh-vmware-ovftool/${short_name}/
```

### GCP

The stemcell pipelines currently run on a Concourse instance configured here:

- https://github.com/cloudfoundry/concourse-infra-for-fiwg

Concourse publishes its artifacts to GCS.

#### Create Buckets

```shell
export gcp_region="europe-west4"

gsutil mb -l "${gcp_region}"  gs://bosh-aws-light-stemcells
gsutil mb -l "${gcp_region}"  gs://bosh-aws-light-stemcells-candidate

gsutil mb -l "${gcp_region}"  gs://bosh-gce-light-stemcell-ci-terraform-state

gsutil mb -l "${gcp_region}"  gs://bosh-gce-light-stemcells
gsutil mb -l "${gcp_region}"  gs://bosh-gce-light-stemcells-candidate
gsutil mb -l "${gcp_region}"  gs://bosh-gce-raw-stemcells-new

gsutil mb -l "${gcp_region}"  gs://bosh-core-stemcells
gsutil mb -l "${gcp_region}"  gs://bosh-core-stemcells-candidate
gsutil mb -l "${gcp_region}"  gs://bosh-os-images
gsutil mb -l "${gcp_region}"  gs://bosh-stemcell-triggers
```

#### Make Buckets Publicly Readable

```shell
gsutil iam ch allUsers:objectViewer gs://bosh-os-images

gsutil iam ch allUsers:objectViewer gs://bosh-core-stemcell
gsutil iam ch allUsers:objectViewer gs://bosh-core-stemcells-candidate

gsutil iam ch allUsers:objectViewer gs://bosh-aws-light-stemcells
gsutil iam ch allUsers:objectViewer gs://bosh-aws-light-stemcells-candidate

gsutil iam ch allUsers:objectViewer gs://bosh-gce-light-stemcells
gsutil iam ch allUsers:objectViewer gs://bosh-gce-light-stemcells-candidate
```

#### Set Versioning

```shell
gsutil versioning set on gs://bosh-stemcell-triggers
```

#### Configure Firewall

The `default-allow-internal` firewall rule should allow the subnet `10.0.0.0/8`
on all ports:

```shell
gcloud compute firewall-rules update default-allow-internal --source-ranges 10.0.0.0/8
```

#### Create Integration Networks

Create a `stemcell-builder-integration-${subnet_int}` subnetworks need by BATs tests.
Each stemcell line should get its own subnet corresponding to its `subnet_int` equal to
the two digit release year. For example release year 2010 would have `subnet_int="10"`.

Example per [ci/pipeline-vars.yml](ci/pipeline-vars.yml):

```yaml
---
stemcell_details:
  # ... snip
  subnet_int: "10" #! use last two digits of release year: ex 2010 -> 10
  # ... snip
```

Would mean creating the following subnet in GCP:

```shell
# branch: ubuntu-${short_name}
export subnet_int="10"

gcloud compute networks subnets create --network default \
  --range "10.100.${subnet_int}.0/24" "stemcell-builder-integration-${subnet_int}"
```

### AWS

Concourse will want to publish its artifacts. Create IAM users with the
appropriate policy files:

- For stemcells: use the [bosh-core-stemcells IAM policy](ci/bosh-core-stemcells_iam.json).
  Create buckets for stemcells, then give them a public-read policy.
- For OS images: use the [bosh-os-images IAM policy](ci/bosh-os-images_iam.json).
  Create buckets for OS images, then give them a public-read policy.

### OS Images Pipeline Migration

When switching from the old pipeline to the new one, don't forget to:

* update `pipeline.yml` and change the bucket from `bosh-os-images-dev` to
  whatever the public bucket should be
* update the tasks YAML to point to tasks in the `os-images` directory
* rename this directory from `new`

