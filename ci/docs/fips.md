# FIPS stemcells

## access to the fips stemcell buckets
fips stemcells when published in the pipeline
will be put in a private bucket called `bosh-core-stemcells-fips`

if a working groups needs these fips stemcell the can retrieve them with the
[bosh-io-stemcell](https://github.com/concourse/bosh-io-stemcell-resource) concourse resource =>1.2.1

by setting
```
resources:
- name: stemcell
  type: bosh-io-stemcell
  source:
    name: bosh-aws-xen-hvm-ubuntu-jammy-fips-go_agent
    auth:
        access_key: hmac-accesskey
        secret_key: hmac-secretkey
```
for this you need a service account setup with hmac keys
https://cloud.google.com/storage/docs/authentication/hmackeys

## setup access
to setup access permissions for the `bosh-core-stemcells-fips` bucket

### working group actions
a service accunt should be setup in the working group that want to access the fips stemcells.
this account should then be enabled with [hmac keys](https://cloud.google.com/storage/docs/authentication/hmackeys)

#### bucket owner actions
requirements:
- [gcloud](https://cloud.google.com/sdk/docs/install)
- [gsutil](https://cloud.google.com/storage/docs/gsutil_install)

login to the cloud-foundry-310819 project ` gcloud auth login`

setup access for cross project cloud buckets. reference: https://cloud.google.com/dataprep/docs/concepts/gcs-buckets
replace PLACEHOLDER with the service account that is created in the previous steps for example test-dev@myproject.iam.gserviceaccount.com
```
gsutil defacl ch -u PLACEHOLDER gs://bosh-core-stemcells-fips
gsutil acl ch -u PLACEHOLDER:READER gs://bosh-core-stemcells-fips
gsutil -m acl ch -r -u PLACEHOLDER:READER gs://bosh-core-stemcells-fips
```

