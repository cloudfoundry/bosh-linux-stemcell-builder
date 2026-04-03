# BOSH Stemcells

## docker images and vmware ofvtool
When creating a new lts stemcell  you will need to create a folder and upload the appropriate ofvtool
in to the gcp bucket `bosh-vmware-ovftool`

```shell
gsutil cp MY_OVFTOOL_FILE gs://bosh-vmware-ovftool/MYOS/
```

example:

```shell
gsutil cp VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle gs://bosh-vmware-ovftool/jammy/
```

## AWS
Concourse will want to publish its artifacts. Create an IAM user with the
[bosh-core-stemcells iam policy file](bosh-core-stemcells_iam.json).
Create buckets for stemcells, then give it a public-read policy...

# OS Images
When switching from the old pipeline to the new one, don't forget to...

 * update `pipeline.yml` and change the bucket from `bosh-os-images-dev` to whatever the public bucket should be
 * update the tasks YAML which is point to tasks in the directory of `os-images`
 * rename this directory from `new`

## AWS

Concourse will want to publish its artifacts. Create an IAM user with the
[bosh-os-images iam policy file](bosh-os-images_iam.json).
Create buckets for OS Images, then give it a public-read policy...


## GCP
The stemcell pipelines currently run on a Concourse instance configured here:
- https://github.com/cloudfoundry/concourse-infra-for-fiwg

Concourse will want to publish its artifacts on gcs.

Create the needed buckets

```shell
gsutil mb -l europe-west4  gs://bosh-aws-light-stemcells
gsutil mb -l europe-west4  gs://bosh-aws-light-stemcells-candidate

gsutil mb -l europe-west4  gs://bosh-gce-light-stemcell-ci-terraform-state

gsutil mb -l europe-west4  gs://bosh-gce-light-stemcells
gsutil mb -l europe-west4  gs://bosh-gce-light-stemcells-candidate
gsutil mb -l europe-west4  gs://bosh-gce-raw-stemcells-new
gsutil mb -l europe-west4  gs://bosh-gce-light-stemcell-ci-terraform-state

gsutil mb -l europe-west4  gs://bosh-core-stemcells
gsutil mb -l europe-west4  gs://bosh-core-stemcells-candidate
gsutil mb -l europe-west4  gs://bosh-os-images
gsutil mb -l europe-west4  gs://bosh-stemcell-triggers
gsutil mb -l europe-west4  gs://bosh-gce-light-stemcell-ci-terraform-state
```

Make buckets publicly readable

```shell
gsutil iam ch allUsers:objectViewer gs://bosh-os-images

gsutil iam ch allUsers:objectViewer gs://bosh-core-stemcell
gsutil iam ch allUsers:objectViewer gs://bosh-core-stemcells-candidate

gsutil iam ch allUsers:objectViewer gs://bosh-aws-light-stemcells
gsutil iam ch allUsers:objectViewer gs://bosh-aws-light-stemcells-candidate

gsutil iam ch allUsers:objectViewer gs://bosh-gce-light-stemcells
gsutil iam ch allUsers:objectViewer gs://bosh-gce-light-stemcells-candidate
```

Set versioning on the stemcell trigger bucket

```shell
gsutil versioning set on gs://bosh-stemcell-triggers
```

The `default-allow-internal` should have the following subnet `10.0.0.0/8` on all ports

```shell
gcloud compute firewall-rules update default-allow-internal --source-ranges 10.0.0.0/8
```

Create the bosh-integration networks for our tests and bats tests

Each stemcell line should get its own subnet that will correspond to its `subnet_int`.

example:
- subnet_id=44
-- subnet_range=10.100.44.0/24
-- subnet_name=bosh-integration-44

```shell
# master
gcloud compute networks subnets create --network default --range 10.100.0.0/24 bosh-integration-0
# 1.x
gcloud compute networks subnets create --network default --range 10.100.1.0/24 bosh-integration-1
```
