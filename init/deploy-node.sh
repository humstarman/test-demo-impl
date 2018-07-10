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
FILE=info.env
if [ -f ./$FILE ]; then
  source ./$FILE
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no environment file found!" 
  echo " - exit!"
  sleep 3
  exit 1
fi
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
getScript $URL/tools docker-config.sh
# 1 download and install docker 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download docker ... "
source ./version
URL=https://download.docker.com/linux/static/stable/x86_64
if [ ! -f docker-${DOCKER_VER}-ce.tgz ]; then
  while true; do
    wget $URL/docker-${DOCKER_VER}-ce.tgz && break
  done
fi
if [[ ! -x "$(command -v docker)" ]]; then
  while true; do
    tar -zxvf docker-${DOCKER_VER}-ce.tgz 
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute docker ... "
    ansible all -m copy -a "src=./docker/ dest=/usr/local/bin mode='a+x'"
    if [[ -x "$(command -v docker)" ]]; then
      echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - docker $DOCKER_VER installed."
      break
    fi
  done
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - docker already existed. "
fi
# 2 config docker
ansible all -m script -a "./docker-config.sh -d /opt/docker"
# 3 deploy docker
mkdir -p ./systemd-unit
FILE=./systemd-unit/docker.service
cat > $FILE <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
FILE=${FILE##*/}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible all -m copy -a "src=./systemd-unit/$FILE dest=/etc/systemd/system"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible all -m shell -a "systemctl daemon-reload"
ansible all -m shell -a "systemctl enable $FILE"
ansible all -m shell -a "systemctl restart $FILE"
## check config
TARGET='10.0.0.0/8'
while true; do
  if docker info | grep $TARGET; then
    break
  else
    sleep 1
    ansible all -m shell -a "systemctl daemon-reload"
    ansible all -m shell -a "systemctl restart $FILE"
  fi
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - docker $DOCKER_VER deployed."
# 4 deploy kubelet
## generate system:node-bootstrapper
if ! kubectl get clusterrolebindings | grep kubelet-bootstrap; then
  kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
fi
## generate kubelet bootstrapping kubeconfig
FILE=mk-kubelet-kubeconfig.sh
cat > $FILE << EOF
#!/bin/bash
:(){
  FILES=\$(find /var/env -name "*.env")

  if [ -n "\$FILES" ]; then
    for FILE in \$FILES
    do
      [ -f \$FILE ] && source \$FILE
    done
  fi
};:
# 设置集群参数
kubectl config set-cluster kubernetes \\
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \\
  --embed-certs=true \\
  --server=\${KUBE_APISERVER} \\
  --kubeconfig=bootstrap.kubeconfig
# 设置客户端认证参数
kubectl config set-credentials kubelet-bootstrap \\
  --token=\${BOOTSTRAP_TOKEN} \\
  --kubeconfig=bootstrap.kubeconfig
# 设置上下文参数
kubectl config set-context default \\
  --cluster=kubernetes \\
  --user=kubelet-bootstrap \\
  --kubeconfig=bootstrap.kubeconfig
# 设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
yes | mv bootstrap.kubeconfig /etc/kubernetes/
EOF
ansible all -m script -a ./$FILE
##  generate kubelet systemd unit
mkdir -p ./systemd-unit
FILE=./systemd-unit/kubelet.service
cat > $FILE <<"EOF"
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=-/var/env/env.conf
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet \
  --network-plugin=cni \
  --cni-conf-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/cni/bin \
  --fail-swap-on=false \
  --pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest \
  --cgroup-driver=cgroupfs \
  --address=${NODE_IP} \
  --hostname-override=${NODE_IP} \
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
  --cert-dir=/etc/kubernetes/ssl \
  --cluster-dns=${CLUSTER_DNS_SVC_IP} \
  --cluster-domain=${CLUSTER_DNS_DOMAIN} \
  --hairpin-mode promiscuous-bridge \
  --allow-privileged=true \
  --serialize-image-pulls=false \
  --logtostderr=true \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --v=2
ExecStartPost=/sbin/iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -s 172.17.0.0/12 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -s 192.168.1.0/16 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -p tcp --dport 4194 -j DROP
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
FILE=${FILE##*/}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible all -m copy -a "src=./systemd-unit/$FILE dest=/etc/systemd/system"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible all -m shell -a "systemctl daemon-reload"
ansible all -m shell -a "systemctl enable $FILE"
ansible all -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."
# 5 deploy kube-proxy 
## generate kube-proxy pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate kube-proxy pem ... "
SSL_DIR=./ssl/kube-proxy
mkdir -p $SSL_DIR 
FILE=$SSL_DIR/kube-proxy-csr.json
cat > $FILE << EOF
{
  "CN": "system:kube-proxy",
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
cd $SSL_DIR && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy && \
  cd -
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute kube-proxy pem ... "
ansible all -m copy -a "src=${SSL_DIR}/ dest=/etc/kubernetes/ssl"
## generate kube-proxy bootstrapping kubeconfig
FILE=mk-kube-proxy-kubeconfig.sh
cat > $FILE << EOF
#!/bin/bash
:(){
  FILES=\$(find /var/env -name "*.env")

  if [ -n "\$FILES" ]; then
    for FILE in \$FILES
    do
      [ -f \$FILE ] && source \$FILE
    done
  fi
};:
# 设置集群参数
kubectl config set-cluster kubernetes \\
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \\
  --embed-certs=true \\
  --server=\${KUBE_APISERVER} \\
  --kubeconfig=kube-proxy.kubeconfig
# 设置客户端认证参数
kubectl config set-credentials kube-proxy \\
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \\
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \\
  --embed-certs=true \\
  --kubeconfig=kube-proxy.kubeconfig
# 设置上下文参数
kubectl config set-context default \\
  --cluster=kubernetes \\
  --user=kube-proxy \\
  --kubeconfig=kube-proxy.kubeconfig
# 设置默认上下文
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
yes | mv kube-proxy.kubeconfig /etc/kubernetes/
EOF
ansible all -m script -a ./$FILE
##  generate kube-proxy systemd unit
mkdir -p ./systemd-unit
FILE=./systemd-unit/kube-proxy.service
cat > $FILE <<"EOF"
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/var/env/env.conf
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/usr/local/bin/kube-proxy \
  --bind-address=${NODE_IP} \
  --hostname-override=${NODE_IP} \
  --cluster-cidr=${SERVICE_CIDR} \
  --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \
  --logtostderr=true \
  --proxy-mode=iptables \
  --masquerade-all \
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
FILE=${FILE##*/}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible all -m copy -a "src=./systemd-unit/$FILE dest=/etc/systemd/system"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible all -m shell -a "systemctl daemon-reload"
ansible all -m shell -a "systemctl enable $FILE"
ansible all -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."
