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

# 1 deploy docker
COMPONENT=docker
## 1.1 cp docker 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp $COMPONENT component... "
BIN=/usr/local/bin
TMP=/tmp/$COMPONENT-component
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $BIN && \
  yes | cp docker docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-init docker-proxy docker-runc $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=$BIN mode='a+x'"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT components distributed."
## 1.2 config docker
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - configure $COMPONENT ..."
ansible new -m script -a ./docker-config.sh
## 1.3 cp docker systemd unit
SYSTEMD=/etc/systemd/system
FILE=${COMPONENT}.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible new -m copy -a "src=${SYSTEMD}/$FILE dest=${SYSTEMD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible new -m shell -a "systemctl daemon-reload"
ansible new -m shell -a "systemctl enable $FILE"
ansible new -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."
## 1.4 check docker config
TARGET='10.0.0.0/8'
while true; do
  if docker info | grep $TARGET; then
    break
  else
    sleep 1
    ansible new -m shell -a "systemctl daemon-reload"
    ansible new -m shell -a "systemctl restart $FILE"
  fi
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."

# 2 deploy kubelet
COMPONENT=kubelet
## 2.1 generate kubelet bootstrapping kubeconfig
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
mv bootstrap.kubeconfig /etc/kubernetes/
EOF
ansible new -m script -a ./$FILE
##  2.2 cp kubelet systemd unit
SYSTEMD=/etc/systemd/system
FILE=${COMPONENT}.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible new -m copy -a "src=${SYSTEMD}/$FILE dest=${SYSTEMD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible new -m shell -a "systemctl daemon-reload"
ansible new -m shell -a "systemctl enable $FILE"
ansible new -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."

# 3 deploy kube-proxy 
COMPONENT=kube-proxy
## 3.1 cp kube-proxy pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp $COMPONENT pem ... "
TMP=/tmp/${COMPONENT}-ssl
SSL=/etc/kubernetes/ssl
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $SSL && \
  yes | cp ${COMPONENT}-key.pem ${COMPONENT}.pem $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=$SSL"
## 3.2 generate kube-proxy bootstrapping kubeconfig
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
mv kube-proxy.kubeconfig /etc/kubernetes/
EOF
ansible new -m script -a ./$FILE
##  3.3 cp kube-proxy systemd unit
SYSTEMD=/etc/systemd/system
FILE=${COMPONENT}.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible new -m copy -a "src=${SYSTEMD}/$FILE dest=${SYSTEMD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible new -m shell -a "systemctl daemon-reload"
ansible new -m shell -a "systemctl enable $FILE"
ansible new -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."

# 4 deply HA based on nginx
NODE_EXISTENCE=true
if [ ! -f ./node.csv ]; then
  NODE_EXISTENCE=false
else
  if [ -z "$(cat ./node.csv)" ]; then
    NODE_EXISTENCE=false
  fi
fi
if ! $NODE_EXISTENCE; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - no node existed."
  exit 0
fi
COMPONENT=nginx-proxy
## 4.1 generate nginx.conf
MASTER=$(sed s/","/" "/g ./master.csv)
NEW=$(sed s/","/" "/g ./new.csv)
DOCKER=$(which docker)
NGINX_CONF_DIR=/etc/nginx
FILE=nginx.conf
cat > $FILE << EOF
error_log stderr notice;

worker_processes auto;
events {
  multi_accept on;
  use epoll;
  worker_connections 1024;
}

stream {
    upstream kube_apiserver {
        least_conn;
EOF
for ip in $MASTER; do
  cat >> $FILE << EOF
        server $ip:6443;
EOF
done
for ip in $NEW; do
  cat >> $FILE << EOF
        server $ip:6443;
EOF
done
cat >> $FILE << EOF
    }

    server {
        listen        0.0.0.0:6443;
        proxy_pass    kube_apiserver;
        proxy_timeout 10m;
        proxy_connect_timeout 1s;
    }
}
EOF
ansible node -m shell -a "if [ -d $NGINX_CONF_DIR ]; then echo  - $NGINX_CONF_DIR already existed.; else mkdir -p $NGINX_CONF_DIR; fi"
ansible node -m copy -a "src=$FILE dest=$NGINX_CONF_DIR"
## 4.2 restart nginx-proxy.service
FILE=${COMPONENT}.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart $FILE ... "
ansible node -m shell -a "systemctl daemon-reload"
ansible node -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - HA nodes restarted."  
exit 0
