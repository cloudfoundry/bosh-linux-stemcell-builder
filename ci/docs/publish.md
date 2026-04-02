# Publish a stemcell.
## Verify stemcell builds
Whenever a USN (Ubuntu Security Notice) is published, a ticket is automaticly created in the community-stemcell board (https://github.com/orgs/cloudfoundry/projects/4).
There would also be a notification in the #bosh-private channel of the Cloud Foundry slack.

A USN triggers the stemcell build pipeline, when everything is successfully built, we can publish the new candidate stemcell version.
Please check the latest build of the aggregate-candidate-stemcells job of the stemcell line you need to release (aggregate-candidate-stemcells-1.x),
you should see a successful build which was triggered by the USN notice.
Then, in the stemcells-publisher pipeline, check if google and aws light stemcells were successfully built as a result of the USN.

## Publish stemcells
In order to publish new stemcells, trigger a build of the publish-ubuntu-jammy-1 job (e.g. https://bosh.ci.cloudfoundry.org/teams/main/pipelines/stemcells-publisher/jobs/publish-ubuntu-jammy-1).
When this job is finished, new stemcell versions will be availeble on bosh.io and a github draft release created on
https://github.com/cloudfoundry/bosh-linux-stemcell-builder/releases.
Check the draft release if it has the correct usns and cves and add extra information if necessary in the release notes and publish the github release.