#!/bin/bash
set -e
# 0 set env
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
# 1 download & install Calicoctl 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download CFSSL ... "
VER=v3.1.3
URL=https://github.com/projectcalico/calicoctl/releases/download/$VER/calicoctl-linux-amd64
if [[ ! -f calicoctl ]]; then
  while true; do
    wget $URL
    mv calicoctl-linux-amd64 calicoctl
    chmod +x calicoctl
    ansible master -m copy -a "src=./calicoctl dest=/usr/local/bin mode='a+x'"
    if [[ -x "$(command -v calicoctl)" ]]; then
      echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Calicaoctl installed."
      break
    fi
  done
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL already existed. "
  ansible master -m copy -a "src=./calicoctl dest=/usr/local/bin mode='a+x'"
fi

# 2 make configure file 
ansible master -m shell -a "mkdir -p /etc/calico"
FILE=calicoctl.cfg
cat > $FILE << EOF
apiVersion: v1
kind: calicoApiConfig
metadata:
spec:
  etcdEndpoints: ${ETCD_ENDPOINTS}
  etcdKeyFile: /etc/kubernetes/ssl/kubernetes-key.pem
  etcdCertFile: /etc/kubernetes/ssl/kubernetes.pem
  etcdCACertFile: /etc/kubernetes/ssl/ca.pem
EOF
ansible master -m copy -a "src=./$FILE dest=/etc/calico"
exit 0
