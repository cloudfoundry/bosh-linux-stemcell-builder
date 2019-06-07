#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf ./openssl
mkdir -p openssl

curl_five_times "openssl/openssl.tar.gz" "https://www.openssl.org/source/openssl-1.1.1c.tar.gz"

echo "f6fb3079ad15076154eda9413fed42877d668e7069d9b87396d0804fdb3f4c90 openssl/openssl.tar.gz" | sha256sum -c -

