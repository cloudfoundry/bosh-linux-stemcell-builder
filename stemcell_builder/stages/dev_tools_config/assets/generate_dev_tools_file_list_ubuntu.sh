#!/usr/bin/env bash

for package_name in \
  autoconf \
  automake \
  binutils \
  bison \
  build-essential \
  cmake \
  cpp \
  cpp-4.8 \
  debhelper \
  dkms \
  dpkg-dev \
  flex \
  g++ \
  g++-4.8 \
  gcc \
  gcc-4.8 \
  gettext \
  intltool-debian \
  libmpc3 \
  libtool \
  m4 \
  make \
  patch \
  po-debconf \
; do
  dpkg-query -L $package_name | xargs file | grep -Ev ':\s+directory\s+$' | awk -F ':' '{ print $1 }'
done
