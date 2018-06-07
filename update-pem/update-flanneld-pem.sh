#!/bin/bash

set -e

# 0 set env
:(){
  FILES=$(find /var/env -name "*.env")

  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:

# 1 update flanneld pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - update flanneld pem ... "
mkdir -p ./ssl/flanneld
FILE=./ssl/flanneld/flanneld-csr.json
cat > $FILE << EOF
{
  "CN": "flanneld",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
cd ./ssl/flanneld && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes flanneld-csr.json | cfssljson -bare flanneld && \
  cd -

# 2 distribute flannel pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute flannel pem ... "
ansible all -m copy -a "src=./ssl/flanneld/ dest=/etc/flanneld/ssl"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - flanneld pem updated. "
exit 0
