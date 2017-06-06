#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

mv director-state/* .
mv director-state/.bosh $HOME/

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

$bosh_cli delete-env director.yml -l director-creds.yml
