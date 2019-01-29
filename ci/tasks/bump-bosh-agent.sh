#!/bin/bash -eux

git clone bosh-linux-stemcell-builder bosh-linux-stemcell-builder-out

version=$( cat bosh-agent/.resource/version )

cp bosh-agent/.resource/metalink.meta4 bosh-linux-stemcell-builder-out/stemcell_builder/stages/bosh_go_agent/assets/
cp bosh-agent/.resource/version bosh-linux-stemcell-builder-out/stemcell_builder/stages/bosh_go_agent/assets/bosh-agent-version

pushd bosh-linux-stemcell-builder-out
	if [ "$(git status --porcelain)" != "" ]; then
		git add -A
		git config --global user.email "ci@localhost"
		git config --global user.name "CI Bot"
		git commit -m "bump bosh-agent/$version"
	fi
popd
