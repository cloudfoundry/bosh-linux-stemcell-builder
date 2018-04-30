#!/bin/bash

function build() {
  echo $PWD

  /opt/bosh/ci/docker/run os-image-stemcell-builder
  whoami | grep ubuntu
  if [[ "$?" -eq "0" ]]; then
    echo "You're now ready to continue from the Build Steps section."
  else
    echo "Couldn't find user 'ubuntu'."
    exit 1
  fi

  bundle install --local

  # TODO(cdutra): build os image
}

build
