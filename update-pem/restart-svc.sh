#!/bin/bash

echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart Kubernetes componenets ..."
COMPONENTS="etcd flanneld kube-apiserver kube-controller-manager kube-scheduler docker kubelet kube-proxy"
ansible all -m shell -a "systemctl daemon-reload"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart $COMPONENT ..."
  ansible all -m shell -a "systemctl restart $COMPONENT"
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes componenets restarted."
exit 0
