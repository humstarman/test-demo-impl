#!/bin/bash

echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - check CFSSL ... "
CFSSL_VER=R1.2
URL=https://pkg.cfssl.org/$CFSSL_VER
if [[ ! -x "$(command -v cfssl)" && ! -x "$(command -v cfssljson)" && ! -x "$(command -v cfssl-certinfo)" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - no CFSSL found in PATH."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download CFSSL ..."
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
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL already existed. "
fi
