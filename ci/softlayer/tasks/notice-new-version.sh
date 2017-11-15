#!/usr/bin/env bash

set -e -x

: ${SLACK_URL:?}

[ -f published-stemcell/version ] || exit 1

published_version=$(cat published-stemcell/version)

echo -e "\n\033[32m[INFO] Installing slacktee:\033[0m"

function post_to_slack () {
  SLACK_MESSAGE="$1"

  curl -X POST --data "payload={\"text\": \"new stemcell version: ${SLACK_MESSAGE} is coming!\"}" ${SLACK_URL}
}

post_to_slack "$published_version"