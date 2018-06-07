#!/bin/bash

set -e

# 1 update TLS pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - update etcd TLS pem ... "
mkdir -p ./ssl/etcd
FILE=./ssl/etcd/etcd-csr.json
cat > $FILE << EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
EOF
MASTER=$(sed s/","/" "/g ./master.csv)
#echo $MASTER
i=0
N_MASTER=$(echo $MASTER | wc | awk -F ' ' '{print $2}')
#echo $N_MASTER
for ip in $MASTER; do
  i=$[i+1]
  #echo $i
  ip=\"$ip\"
  if [[ $i < $N_MASTER ]]; then
    ip+=,
  fi
  cat >> $FILE << EOF
    $ip
EOF
done
cat >> $FILE << EOF
  ],
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

cd ./ssl/etcd && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes etcd-csr.json | cfssljson -bare etcd && \
  cd -

# 2 distribute etcd pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute etcd pem ... "
ansible all -m copy -a "src=ssl/etcd/ dest=/etc/etcd/ssl"
ansible all -m copy -a "src=ssl/etcd/ dest=/etc/kubernetes/ssl"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - etcd pem updated. "
exit 0
