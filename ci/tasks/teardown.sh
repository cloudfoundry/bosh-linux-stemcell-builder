#!/usr/bin/env bash

set -ex

mv director-state/* .
mv director-state/.bosh $HOME/
alias bosh-cli=$(realpath bosh-cli/bosh-cli-*)

bosh-cli delete-env director.yml -l director-creds.yml
