#!/bin/bash

set -e

# 1 set env
:(){
  FILES=$(find /var/env -name "*.env")

  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:

# 2 make ansible file, and generate kubernetes pem
ANSIBLE=/etc/ansible/hosts
GROUP=apiserver
echo "" >> $ANSIBLE
echo "[${GROUP}]" >> $ANSIBLE
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate kubernetes pem ... "
TMP=/tmp/kubernetes-ssl
mkdir -p $TMP 
FILE=${TMP}/kubernetes-csr.json
cat > $FILE << EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
EOF
MASTER=$(sed s/","/" "/g ./master.csv)
for ip in $MASTER; do
  echo $ip >> $ANSIBLE
  cat >> $FILE << EOF
    "$ip",
EOF
done
NEW=$(sed s/","/" "/g ./new.csv)
for ip in $NEW; do
  echo $ip >> $ANSIBLE
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
cd $TMP && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
  cd -

# 3 distribute kubernetes pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute kubernetes pem ... "
ansible $GROUP -m copy -a "src=${TMP}/ dest=/etc/kubernetes/ssl"

# 4 pepaare ennviorment variable about the number of masters
N2SET=3
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc | awk -F ' ' '{print $2}')
NEW=$(sed s/","/" "/g ./new.csv)
N_NEW=$(echo $NEW | wc -l)
N_TOTAL=$[${N_MASTER}+${N_NEW}]
if [[ "${N_TOTAL}" > "$N2SET" ]]; then
  if [[ "$[${N_TOTAL}%2]" == "1" ]]; then
    N2SET=$N_TOTAL
  else
    N2SET=$[${N_TOTAL}+1]
  fi
fi
  
# 5 deploy kube-apiserver
TMP=/tmp/systemd-unit
mkdir -p $TMP 
FILE=${TMP}/kube-apiserver.service
cat > $FILE << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/var/env/env.conf
ExecStart=/usr/local/bin/kube-apiserver \\
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --advertise-address=\${NODE_IP} \\
  --bind-address=0.0.0.0 \\
  --insecure-bind-address=0.0.0.0 \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all=rbac.authorization.kubernetes.io/v1 \\
  --kubelet-https=true \\
  --enable-bootstrap-token-auth \\
  --token-auth-file=/etc/kubernetes/token.csv \\
  --service-cluster-ip-range=\${SERVICE_CIDR} \\
  --service-node-port-range=\${NODE_PORT_RANGE} \\
  --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --client-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem \\
  --etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --etcd-servers=\${ETCD_ENDPOINTS} \\
  --enable-swagger-ui=true \\
  --allow-privileged=true \\
  --apiserver-count=$N2SET \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/lib/audit.log \\
  --event-ttl=1h \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
FILE=${FILE##*/}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible $GROUP -m copy -a "src=$TMP/$FILE dest=/etc/systemd/system"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible $GROUP -m shell -a "systemctl daemon-reload"
ansible $GROUP -m shell -a "systemctl enable $FILE"
ansible $GROUP -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."

# 6 deploy kube-controller-manager
SYSTEMD=/etc/systemd/system
FILE=kube-controller-manager.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible new -m copy -a "src=${SYSTEMD}/$FILE dest=${SYSTEMD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible $GROUP -m shell -a "systemctl daemon-reload"
ansible $GROUP -m shell -a "systemctl enable $FILE"
ansible $GROUP -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."

# 7 deploy kube-scheduler
SYSTEMD=/etc/systemd/system
FILE=kube-scheduler.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible new -m copy -a "src=${SYSTEMD}/$FILE dest=${SYSTEMD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible $GROUP -m shell -a "systemctl daemon-reload"
ansible $GROUP -m shell -a "systemctl enable $FILE"
ansible $GROUP -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."
exit 0
