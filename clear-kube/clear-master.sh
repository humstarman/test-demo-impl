#!/bin/bash
# stop svc
systemctl stop kube-apiserver kube-controller-manager kube-scheduler
# clear files
# 删除 kube-apiserver 工作目录
rm -rf /var/run/kubernetes
# 删除 systemd unit 文件
rm -rf /etc/systemd/system/{kube-apiserver,kube-controller-manager,kube-scheduler}.service
# 删除程序文件
rm -rf /usr/local/bin/{kube-apiserver,kube-controller-manager,kube-scheduler}
# 删除证书文件
rm -rf /etc/flanneld/ssl /etc/kubernetes/ssl
