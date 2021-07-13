#!/usr/bin/env bash

declare -a PACKAGES

PACKAGES=( \
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
  cpp-5 \
  cpp-7 \
  g++-5 \
  g++-7 \
  gcc-5 \
  gcc-6 \
  gcc-7 \
  gcc-5-base \
  gcc-6-base \
  gcc-7-base
)

for package_name in ${PACKAGES[*]} ; do
  dpkg-query -L "$package_name" | xargs file | grep -Ev ':\s+directory\s*$' | awk -F ':' '{ print $1 }'
done
