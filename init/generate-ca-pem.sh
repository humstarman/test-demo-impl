#!/bin/bash
# 0 set env
YEAR=1
# 1 download and install CFSSL
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download CFSSL ... "
CFSSL_VER=R1.2
URL=https://pkg.cfssl.org/$CFSSL_VER
if [[ ! -f cfssl || ! -f cfssljson || ! -f cfssl-certinfo ]]; then
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
  mv cfssl /usr/local/bin/cfssl
  mv cfssljson /usr/local/bin/cfssljson
  mv cfssl-certinfo /usr/local/bin/cfssl-certinfo
fi
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate CA pem ... "
# 2 generate template
mkdir -p ./ssl/ca
cd ./ssl/ca && \
  cfssl print-defaults config > config.json && \
  cfssl print-defaults csr > csr.json && \
  cd -
# 3 generate ca
HOUR=$[8760*${YEAR}]
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
exit 0
