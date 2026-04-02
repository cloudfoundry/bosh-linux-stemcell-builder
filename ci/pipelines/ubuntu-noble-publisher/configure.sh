#!/usr/bin/env bash

set -e

FLY="${FLY_CLI:-fly}"

until "$FLY" -t "${CONCOURSE_TARGET:-stemcell}" status;do
  "$FLY" -t "${CONCOURSE_TARGET:-stemcell}" login
  sleep 1
done

pipeline_config=$(mktemp)
ytt -f "$(dirname "${0}")" > "${pipeline_config}"

"$FLY" -t "${CONCOURSE_TARGET:-stemcell}" set-pipeline \
  --team=stemcell \
  -p ubuntu-noble-publisher \
  -c "${pipeline_config}"
