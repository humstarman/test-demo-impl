#!/bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart Kubernetes componenets ..."
COMPONENTS="etcd flanneld kube-apiserver kube-controller-manager kube-scheduler docker kubelet kube-proxy"
MASTER_COMPONENTS="etcd kube-apiserver kube-controller-manager kube-scheduler"
GROUP="all"
ansible $GROUP -m shell -a "systemctl daemon-reload"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart $COMPONENT ..."
  if echo $MASTER_COMPONENTS | grep $COMPONENT > /dev/null 2>&1; then
    GROUP="master"
  else
    GROUP="all"
  fi
  ansible $GROUP -m shell -a "systemctl restart $COMPONENT"
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes componenets restarted."
exit 0
