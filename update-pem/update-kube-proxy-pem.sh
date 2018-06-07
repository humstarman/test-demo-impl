#!/bin/bash

# 0 set env
set -e
:(){
  FILES=$(find /var/env -name "*.env")

  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:

# 1 update kube-proxy pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - update kube-proxy pem ... "
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
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - kube-proxy pem updated."

# 2 update kube-proxy kubeconfig
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - update kube-proxy kubeconfig file ... "
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
ansible all -m script -a ./$FILE
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - kube-proxy kubeconfig file updated. "
exit 0
