#!/bin/bash
set -e
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp CA pem ... "
TMP=/tmp/ca-ssl
SSL=/etc/kubernetes/ssl
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $SSL && \
  yes | cp ca-config.json ca.csr ca-csr.json ca-key.pem ca.pem $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=$SSL"
exit 0
