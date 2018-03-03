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
)

if [ "$1" == 'xenial' ]; then
  PACKAGES+=(cpp-5 g++-5 gcc-5 gcc-5-base gcc-6-base)
else
  PACKAGES+=(cpp-4.8 g++-4.8 gcc-4.8)
fi

for package_name in ${PACKAGES[*]} ; do
  dpkg-query -L "$package_name" | xargs file | grep -Ev ':\s+directory\s*$' | awk -F ':' '{ print $1 }'
done
