#!/bin/bash
set -e
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp Kubernetes master & node components ... "
BIN=/usr/local/bin
TMP=/tmp/k8s-node-components
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $BIN && \
  cp kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy kubectl $TMP && \
  cd - 
ansible new -m copy -a "src=${TMP}/ dest=$BIN mode='a+x'"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes master & node components distributed."
exit 0
