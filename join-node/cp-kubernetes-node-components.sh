#!/bin/bash
set -e
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp Kubernetes node components ... "
BIN=/usr/local/bin
TMP=/tmp/k8s-node-components
mkdir -p $TMP
cd $BIN && \
  cp kubelet kube-proxy kubectl $TMP && \
  cd - 
ansible new -m copy -a "src=${TMP}/ dest=$BIN mode='a+x'"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes node components distributed."
exit 0
