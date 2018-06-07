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

# 1 update kubelet bootstrapping kubeconfig
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - update kubelet bootstrapping kubeconfig file ... "
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
ansible all -m script -a ./$FILE
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - kubelet bootstrapping kubeconfig file updated."
exit 0
