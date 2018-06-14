#!/bin/bash
# stop svc
systemctl stop kubelet kube-proxy flanneld docker
# clear files
# umount kubelet 挂载的目录
mount | grep '/var/lib/kubelet'| awk '{print $3}'|xargs sudo umount
# 删除 kubelet 工作目录
rm -rf /var/lib/kubelet
# 删除 docker 工作目录
rm -rf /var/lib/docker
# 删除 flanneld 写入的网络配置文件
rm -rf /var/run/flannel/
# 删除 docker 的一些运行文件
rm -rf /var/run/docker/
# 删除 systemd unit 文件
rm -rf /etc/systemd/system/{kubelet,docker,flanneld}.service
# 删除程序文件
rm -rf /usr/local/bin/{kubelet,docker,flanneld}
# 删除证书文件
rm -rf /etc/flanneld/ssl /etc/kubernetes/ssl
# clear iptables
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
# del docker and flannel net bridges
ip link del flannel.1
ip link del docker0
