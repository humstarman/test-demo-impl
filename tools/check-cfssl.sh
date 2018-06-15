#!/bin/bash

set -e

# 1 check in PATH
if [[ -x "$(command -v cfssl)" && -x "$(command -v cfssljson)" && -x "$(command -v cfssl-certinfo)" ]]; then
  # cfssl suite alreay in path
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL suite found in PATH."
  exit 0
fi
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - CFSSL suite not found in PATH !!!"

# 2 check in ./
if [[ -f cfssl && -f cfssljson && -f cfssl-certinfo ]]; then
  THIS_DIR=$(cd "$(dirname "$0")";pwd)
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL suite found in ${THIS_DIR}."
  mv cfssl /usr/local/bin/cfssl
  mv cfssljson /usr/local/bin/cfssljson
  mv cfssl-certinfo /usr/local/bin/cfssl-certinfo
  exit 0
fi

# 3 download and install CFSSL
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download CFSSL ... "
CFSSL_VER=R1.2
URL=https://pkg.cfssl.org/$CFSSL_VER
while true; do
  wget $URL/cfssl_linux-amd64
  chmod +x cfssl_linux-amd64
  mv cfssl_linux-amd64 /usr/local/bin/cfssl
  wget $URL/cfssljson_linux-amd64
  chmod +x cfssljson_linux-amd64
  mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
  wget $URL/cfssl-certinfo_linux-amd64
  chmod +x cfssl-certinfo_linux-amd64
  mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
  if [[ -x "$(command -v cfssl)" && -x "$(command -v cfssljson)" && -x "$(command -v cfssl-certinfo)" ]]; then
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL installed."
    break
  fi
done
exit 0
