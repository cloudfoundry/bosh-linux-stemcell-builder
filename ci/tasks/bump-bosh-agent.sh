#!/bin/bash -eux

git clone bosh-linux-stemcell-builder bosh-linux-stemcell-builder-out
pushd bosh-agent-index
  metalink_file=$(git diff HEAD~1 --name-only | tr -d '\n')
popd
cp bosh-agent-index/${metalink_file} bosh-linux-stemcell-builder-out/stemcell_builder/stages/bosh_go_agent/assets/metalink.meta4
pushd bosh-linux-stemcell-builder-out
  if [[ -n $(git status --porcelain)  ]]; then
    echo ${metalink_file} | sed -e 's/^v//' -e 's/\.meta4$//' > \
      stemcell_builder/stages/bosh_go_agent/assets/bosh-agent-version
    git add -A
    git config --global user.email "ci@localhost"
    git config --global user.name "CI Bot"
    git commit -m "bump bosh-agent"
  fi
popd
