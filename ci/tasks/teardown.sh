#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby ruby

mv director-state/* .
mv director-state/.bosh $HOME/

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

$bosh_cli clean-up -n --all
$bosh_cli delete-env -n director.yml -l director-creds.yml
