# Publish a stemcell

## Verify stemcells have built

The following CI build groups process USN(s), and post a message to the 
`#bosh-private` channel in the
[Cloud Foundry slack](https://cloudfoundry.slack.com)
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-jammy-builder?group=automatic-triggers
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-noble-builder?group=automatic-triggers

A USN triggers the stemcell build pipeline to pick up newer packages which
address the USN(s). Before publishing a new stemcell verify the latest build of
`aggregate-candidate-stemcells` job for the stemcell line in question:
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-jammy-builder/jobs/aggregate-candidate-stemcells
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-noble-builder/jobs/aggregate-candidate-stemcells

Look for a successful build triggered by the USN(s).

In the publisher pipelines:
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-jammy-publisher
- https://bosh.ci.cloudfoundry.org/teams/stemcell/pipelines/ubuntu-noble-publisher

verify that the lite stemcell builds for Google and AWS have been successfully
triggered by the USN(s).

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
