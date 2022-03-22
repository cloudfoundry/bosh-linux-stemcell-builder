#!/bin/bash

set -e

source $(dirname $0)/../../../stemcell_builder/lib/helpers.sh

run_in_chroot $chroot "
  pwd
  exit 12
  exit 34
  "
