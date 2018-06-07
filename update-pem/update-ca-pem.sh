#!/bin/bash

YEAR=1
HOUR=$[8760*${YEAR}]

echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - update CA pem ... "
# 1 generate template
mkdir -p ./ssl/ca
cd ./ssl/ca && \
  cfssl print-defaults config > config.json && \
  cfssl print-defaults csr > csr.json && \
  cd -

# 2 generate ca
FILE=./ssl/ca/ca-config.json
cat > $FILE << EOF
{
  "signing": {
    "default": {
      "expiry": "${HOUR}h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "${HOUR}h"
      }
    }
  }
}
EOF
FILE=./ssl/ca/ca-csr.json
cat > $FILE << EOF
{
  "CN": "kubernetes",
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

cd ./ssl/ca && \
  cfssl gencert -initca ca-csr.json | cfssljson -bare ca && \
  cd -

# 4 distribute ca pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute CA pem ... "
ansible all -m copy -a "src=ssl/ca/ dest=/etc/kubernetes/ssl"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CA pem updated. "
exit 0
