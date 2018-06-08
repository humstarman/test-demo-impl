#!/bin/bash

set -e

# 1 cp admin pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp admin pem ... "
TMP=/tmp/admin-ssl
SSL=/etc/kubernetes/ssl 
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $SSL && \
  yes | cp admin-key.pem admin.pem $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=/etc/kubernetes/ssl"

# 2 generate kubectl kubeconfig
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate kubectl kubeconfig ... "
FILE=mk-kubectl-kubeconfig.sh
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
  --server=\${KUBE_APISERVER}
# 设置客户端认证参数
kubectl config set-credentials admin \\
  --client-certificate=/etc/kubernetes/ssl/admin.pem \\
  --embed-certs=true \\
  --client-key=/etc/kubernetes/ssl/admin-key.pem \\
  --token=\${BOOTSTRAP_TOKEN}
# 设置上下文参数
kubectl config set-context kubernetes \\
  --cluster=kubernetes \\
  --user=admin
# 设置默认上下文
kubectl config use-context kubernetes
# 添加kubectl的自动补全
IF0=\$(cat /etc/profile | grep "source <(kubectl completion bash)")
if [ -z "\$IF0" ]; then
  echo 'source <(kubectl completion bash)' >> /etc/profile
fi
EOF
ansible new -m script -a ./mk-kubectl-kubeconfig.sh
exit 0
