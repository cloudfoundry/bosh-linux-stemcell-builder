# Publish a stemcell

## Verify stemcell builds

Whenever a USN (Ubuntu Security Notice) is published, a ticket is automatically
created in the community-stemcell board
(https://github.com/orgs/cloudfoundry/projects/4).
There would also be a notification in the #bosh-private channel of the 
Cloud Foundry slack.

A USN triggers the stemcell build pipeline, when everything is successfully
built, we can publish the new candidate stemcell version.
Please check the latest build of the aggregate-candidate-stemcells job of the
stemcell line you need to release (aggregate-candidate-stemcells),
you should see a successful build which was triggered by the USN notice.
Then, in the stemcells-publisher pipeline, check if google and aws light
stemcells were successfully built as a result of the USN.

## Publish stemcells

In order to publish new stemcells, trigger a build of the
`publish-ubuntu-${short_name}-1` job:
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-jammy-publisher/jobs/publish-ubuntu-jammy-1
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-noble-publisher/jobs/publish-ubuntu-noble-1

This job will take around 1h to run. When this job is finished, new stemcell
versions will be available on bosh.io and a GitHub draft release will have been
created at
- https://github.com/cloudfoundry/bosh-linux-stemcell-builder/releases.

Check to see if the draft release has the correct USNs and CVEs, add any extra
information (see below) to the release notes, and publish the GitHub release.

Then [Finalize the draft release on GitHub](https://github.com/cloudfoundry/bosh-linux-stemcell-builder/releases)
- Select the appropriate `Previous Tag` and click "Generate release notes" -
  - Do NOT leave it set to `Auto` as that will result in incorrect release notes.
- Scroll to the bottom; cut-and-paste the "What's Changed" section and paste it
  at the top
- Check the items for correctness; they may have already been published in a
  previous release. Branch merges can confuse GitHub's auto-generated notes.
- Reword the bullet items to convey what was fixed:

| old (bad)                                    | new (good)                                                                                                            |
|----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| 🐞 Fix “Cannot connect to the monit daemon.” | Fixed issue with BOSH service-broker tasks failing under heavy usage with error "Cannot connect to the monit daemon." |
| Installing ethtool in Jammy by @<someone> in | Stemcells now include the networking utility, ethtool, useful for troubleshooting & resolving networking issues.      |
