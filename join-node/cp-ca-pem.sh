#!/bin/bash
set -e
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp CA pem ... "
FROM=/tmp/ca-ssl
TO=/etc/kubernetes/ssl
mkdir -p $FROM
cd $TO && \
  cp ca-config.json ca.csr ca-csr.json ca-key.pem ca.pem $FROM && \
  cd -
ansible new -m copy -a "src=${FROM}/ dest=$TO"
exit 0
