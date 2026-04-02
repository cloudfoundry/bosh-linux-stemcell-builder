# BOSH Stemcells

## docker images and vmware ofvtool
when creating a new lts stemcell e.g: bionic, jammy etc
you will need to create a folder and upload the appropiate ofvtool in to the gcp bucket `bosh-vmware-ovftool`
`gsutil cp MY_OVFTOOL_FILE gs://bosh-vmware-ovftool/MYOS/`
example:
`gsutil cp VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle gs://bosh-vmware-ovftool/jammy/`

## AWS

Concourse will want to publish its artifacts. Create an IAM user with the [required policy](iam_policy.json). Create buckets for stemcells, then give it a public-read policy...

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::bosh-core-stemcells-dev/*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::bosh-core-stemcells-dev"
        }
    ]
}
```

# OS Images

When switching from the old pipeline to the new one, don't forget to...

 * update `pipeline.yml` and change the bucket from `bosh-os-images-dev` to whatever the public bucket should be
 * update the tasks YAML which is point to tasks in the directory of `os-images`
 * rename this directory from `new`

## AWS

Concourse will want to publish its artifacts. Create an IAM user with the [required policy](iam_policy.json). Create buckets for OS Images, then give it a public-read policy...

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
              "s3:PutObject",
              "s3:GetObjectAcl",
              "s3:GetObject",
              "s3:GetObjectVersionAcl",
              "s3:PutObjectAcl",
              "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::bosh-os-images/*"
        },
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
              "s3:ListBucketVersions",
              "s3:ListBucket",
              "s3:GetBucketVersioning"
            ],
            "Resource": "arn:aws:s3:::bosh-os-images"
        }
    ]
}
```

## GCP
as from the bionic line we are hosting the the creating of the stemcells on gcp
the pipeline it self is currently running on a gke hosted concourse see https://github.com/cloudfoundry/bosh-community-stemcell-ci-infra


Concourse will want to publish its artifacts on gcs.

Create the needed buckets
```
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
```
gsutil iam ch allUsers:objectViewer gs://bosh-os-images

gsutil iam ch allUsers:objectViewer gs://bosh-core-stemcell
gsutil iam ch allUsers:objectViewer gs://bosh-core-stemcells-candidate

gsutil iam ch allUsers:objectViewer gs://bosh-aws-light-stemcells
gsutil iam ch allUsers:objectViewer gs://bosh-aws-light-stemcells-candidate

gsutil iam ch allUsers:objectViewer gs://bosh-gce-light-stemcells
gsutil iam ch allUsers:objectViewer gs://bosh-gce-light-stemcells-candidate
```

Set versioning on the stemcell trigger bucket
```
gsutil versioning set on gs://bosh-stemcell-triggers
```

the `default-allow-internal` should have the following subnet `10.0.0.0/8` on all ports
```
gcloud compute firewall-rules update default-allow-internal --source-ranges 10.0.0.0/8
```

create the bosh-intergration networks for our tests and bats tests
each stemcell line should get its own subnet that will corrosponds with its subnet_int
example:
- subnet_id=44
-- subnet_range=10.100.44.0/24
-- subnet_name=bosh-integration-44

```
# master
gcloud compute networks subnets create --network default --range 10.100.0.0/24 bosh-integration-0
# 1.x
gcloud compute networks subnets create --network default --range 10.100.1.0/24 bosh-integration-1
```