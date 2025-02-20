#!/usr/bin/env bash
set -e

declare -a PACKAGES

PACKAGES=( \
  binutils \
  bison \
  build-essential \
  cmake \
  cpp \
  debhelper \
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
  cpp-13 \
  g++-13 \
  gcc-13 \
  gcc-13-base \
  gcc-14-base
)

for package_name in ${PACKAGES[*]} ; do
  if ! dpkg -s "$package_name" &> /dev/null ; then
    echo "$package_name is NOT installed."
  fi
  dpkg-query -L "$package_name" | xargs file | grep -Ev ':\s+directory\s*$|:\s+symbolic link to usr/lib\s*$' | awk -F ':' '{ print $1 }'
done
