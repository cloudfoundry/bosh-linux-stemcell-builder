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
  gcc-14-base \
  clang \
  clang-18 \
  libgcc-s1 \
  libstdc++6 \
  libclang-common-18-dev \
  libclang-cpp18 \
  libclang1-18 \
  libgc1 \
  libllvm18 \
  libobjc-13-dev \
  libobjc4 \
  llvm-18-linker-tools \
)

for package_name in ${PACKAGES[*]} ; do
  if ! dpkg -s "$package_name" &> /dev/null ; then
    echo "$package_name is NOT installed."
  fi
  dpkg-query -L "$package_name" | xargs file | grep -Ev ':\s+directory\s*$|:\s+symbolic link to usr/lib\s*$' | awk -F ':' '{ print $1 }'
done
