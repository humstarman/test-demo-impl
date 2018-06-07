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

# 1 update kubernetes pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - update kubernetes pem ... "
mkdir -p ./ssl/kubernetes
FILE=./ssl/kubernetes/kubernetes-csr.json
cat > $FILE << EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
EOF
MASTER=$(sed s/","/" "/g ./master.csv)
#echo $MASTER
for ip in $MASTER; do
  cat >> $FILE << EOF
    "$ip",
EOF
done
cat >> $FILE << EOF
    "${CLUSTER_KUBERNETES_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
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
cd ./ssl/kubernetes && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
  cd -

# 2 distribute kubernetes pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute kubernetes pem ... "
ansible master -m copy -a "src=./ssl/kubernetes/ dest=/etc/kubernetes/ssl"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - kubernetes pem updated. "
exit 0
