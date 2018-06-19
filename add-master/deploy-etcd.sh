#!/bin/bash

set -e

# 0 set env 
source ./info.env
:(){
  FILES=$(find /var/env -name "*.env")

  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
N_ETCD=3
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w)
if [ ! -f ./node.csv ]; then
  NODE_EXISTENCE=false
else
  if [ -z "$(cat ./node.csv)" ]; then
    NODE_EXISTENCE=false
  fi
fi
if $NODE_EXISTENCE; then
  NODE=$(sed s/","/" "/g ./node.csv)
  N_NODE=$(echo $NODE | wc | awk -F ' ' '{print $2}')
fi
NEW=$(sed s/","/" "/g ./new.csv)
N_NEW=$(echo $NEW | wc -w)

# 1 determining if deploying etcd
N_HEALTHY_ETCD=$(kubectl get componentstatus | grep etcd- | awk -F ' ' '{print $2}' | grep -E "^Healthy$" | wc -l)
if [[ ! "$N_HEALTHY_ETCD" < "$N_ETCD" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - the current number of etcd nodes is ${N_HEALTHY_ETCD}, meeting expecttion value ${N_ETCD}"
  echo " - no need to deploy new etcd node."
  exit 0
fi
TOOLS=${URL}/tools

# 2 if needed, determining which one(s) to deploy
# and, make ansible info
NEEDS=""
ETCD=${MASTER}
GROUP=needs
ANSIBLE=/etc/ansible/hosts
echo "" >> $ANSIBLE
echo "[${GROUP}]" >> $ANSIBLE
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - etcd will be deployed on:"
for IP in $NEW; do
  if ansible etcd --list-hosts | grep ${IP}; then
    NEEDS+="$IP " 
    ETCD+=" $IP" 
    echo " - $IP"
    echo "$IP" >> $ANSIBLE
  fi
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [DEBUG] - etcd: ${ETCD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [DEBUG] - needs: ${NEEDS}"

# 3 cp etcd binary files
COMPONENT="etcd"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp $COMPONENT component... "
BIN=/usr/local/bin
TMP=/tmp/$COMPONENT-component
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $BIN && \
  yes | cp etcd etcdctl $TMP && \
  cd -
ansible $GROUP -m copy -a "src=${TMP}/ dest=$BIN mode='a+x'"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT components distributed."

# 4 check cfssl
curl $TOOLS/check-cfssl.sh | /bin/bash

# 5 generate TLS pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate etcd TLS pem ... "
TMP=/tmp/etcid-ssl
mkdir -p $TMP
FILE=${TMP}/etcd-csr.json
cat > $FILE << EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
EOF
i=0
N_ETCD=$(echo $ETCD | wc | awk -F ' ' '{print $2}')
for ip in $ETCD; do
  i=$[i+1]
  #echo $i
  ip=\"$ip\"
  if [[ $i < $N_ETCD ]]; then
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

cd $TMP && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes etcd-csr.json | cfssljson -bare etcd && \
  cd -

# 3 distribute etcd pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute etcd pem ... "
ansible all -m copy -a "src=${TMP}/ dest=/etc/etcd/ssl"
ansible all -m copy -a "src=${TMP}/ dest=/etc/kubernetes/ssl"

# 4 generate etcd systemd unit
TMP=/tmp/systemd-unit
mkdir -p $TMP
FILE=${TMP}/etcd.service
cat > $FILE << EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
EnvironmentFile=-/var/env/env.conf
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/local/bin/etcd \\
  --name=\${NODE_NAME} \\
  --cert-file=/etc/etcd/ssl/etcd.pem \\
  --key-file=/etc/etcd/ssl/etcd-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd.pem \\
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --initial-advertise-peer-urls=https://\${NODE_IP}:2380 \\
  --listen-peer-urls=https://\${NODE_IP}:2380 \\
  --listen-client-urls=https://\${NODE_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://\${NODE_IP}:2379 \\
  --initial-cluster-token=etcd-cluster-1 \\
  --initial-cluster=\${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
FILE=${FILE##*/}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible $GROUP -m copy -a "src=$TMP/$FILE dest=/etc/systemd/system"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible etcd -m shell -a "systemctl daemon-reload"
ansible etcd -m shell -a "systemctl enable $FILE"
ansible etcd -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - etcd deployed."
exit 0
