# Creating a new stemcell line

### Creating the new stemcells:
1. Get on the current `HEAD` of `bosh-linux-stemcell-builder/master`. 
1. Bump agent and blobstore clients (currently davcli, s3cli, gcscli - see Further References) to their latest versions on `master`
1. Bump os-images for `master`.
1. Build a stemcell in the `bosh:stemcells` pipeline, inform DK when it's passed CI so that he can publish it.


### Cutting the pipelines:
*Below, replace `9999.x` with the stemcell version that was published from master pipeline.*

#### Stemcells and OS Images
1. Create a new branch in `bosh-linux-stemcell-builder` named `9999.x`
1. Using the version of the published stemcell, add some variables to the `ci/configure.sh`
```
	-v stemcell_branch=9999.x \
	-v stemcell_version_key=bosh-stemcell/version-9999.x \
	-v stemcell_version_semver_bump=minor
```
1. Using the version of the published stemcell, add some variables to the `ci/os-image/configure.sh`
```
	-v branch=9999.x
```
1. Update the `configure.sh` scripts to create `bosh:os-image:9999.x` and `bosh:stemcell:9999.x` pipelines.
1. Log in to the `bosh core os images stemcells` AWS account. Go into the `bosh-core-stemcells-candidate` bucket, then the `bosh-stemcell` folder.
1. Update `initial_version` value for the `version` semver resource in `ci/pipeline.yml` and update it to `9999.0.0`
1. Push changes to the branch.
1. Run the configure scripts: `ci/configure.sh` & `ci/os-images/configure.sh`
	1. That creates os-image and stemcell pipelines; check them to make sure that they're pointing to the right repos, branches, and version file.
	2. You can unpause those pipelines. `stemcells:9999.x` will kick off a build.

#### Bosh-Agent
*Below, replace `A.B.x` with the agent version that was shipped with the new stemcells, which can be found in `stemcell_builder/stages/bosh_go_agent/apply.sh`*

##### Agent versioning details
* No pipeline bumps the major version.
* The bosh-agent pipeline (which pulls from `develop`) bumps the minor version - A.*B*.x.
* The bosh-agent:A.B.x pipeline (which pulls from branch `A.B.x`) will bump the *patch* - A.B.*1*, .2, etc.

##### Creating the pipeline
1. Create a new agent branch `A.B.x` (replace with the agent version that was used in the 9999.x stemcell)
1. Copy the pipeline YAML and configure.sh scripts from the previous agent patch branch.
1. In configure.sh, update the pipeline name and `--var` flags.
1. Create a new agent pipeline titled `bosh-agent:A.B.x`.

### Further references
* [spreadsheet with context, links, and directions](https://docs.google.com/spreadsheets/d/11LgvmuR-XxXpKB-UVi91FL0nkITGhoB-G1NHPwfnweo/edit#gid=0) - not open to everyone, probably
* [BOSH DavCLI Repo](https://github.com/cloudfoundry/bosh-davcli)
* [BOSH S3CLI Repo](https://github.com/cloudfoundry/bosh-s3cli)
* [BOSH GCSCLI Repo](https://github.com/cloudfoundry/bosh-gcscli)
