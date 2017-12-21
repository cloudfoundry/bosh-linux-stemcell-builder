#!/usr/bin/env bash

for package_name in \
  binutils \
  bison \
  build-essential \
  cmake \
  cpp \
  debhelper \
  dkms \
  dpkg-dev \
  flex \
  g++ \
  gcc \
  gettext \
  intltool-debian \
  libmpc3 \
  make \
  patch \
  po-debconf \
; do
  (for i in `dpkg-query -W -f '${Package} ' ${package_name}*`; do dpkg -L $i; done) | xargs file | grep -Ev ':\s+directory\s*$' | awk -F ':' '{ print $1 }'
done
