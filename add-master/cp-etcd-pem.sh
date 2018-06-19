#!/bin/bash
set -e
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp etcd pem ... "
TMP=/tmp/etcd-ssl
TO1=/etc/kubernetes/ssl
TO2=/etc/etcd/ssl
mkdir -p $TMP
cd $TO2 && \
  cp etcd-key.pem etcd.pem $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=$TO1"
ansible new -m copy -a "src=${TMP}/ dest=$TO2"
exit 0
