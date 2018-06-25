#!/bin/bash
set -e
# 1 stop node components
COMPONENTS="docker kubelet kube-proxy"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - stop $COMPONENT ..."
  ansible all -m shell -a "systemctl stop $COMPONENT"
done
# 2 replace .service files
## 2.1 docker
DOCKERD=$(which dockerd)
cat > docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=${DOCKERD}
ExecReload=/bin/kill -s HUP \$MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
# 2.2 kubelet
cat > kubelet.service << EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service
[Service]
EnvironmentFile=-/var/env/env.conf
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --cni-bin-dir=/opt/cni/bin \\
  --fail-swap-on=false \\
  --pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest \\
  --cgroup-driver=cgroupfs \\
  --address=\${NODE_IP} \\
  --hostname-override=\${NODE_IP} \\
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --cert-dir=/etc/kubernetes/ssl \\
  --cluster-dns=\${CLUSTER_DNS_SVC_IP} \\
  --cluster-domain=\${CLUSTER_DNS_DOMAIN} \\
  --hairpin-mode promiscuous-bridge \\
  --allow-privileged=true \\
  --serialize-image-pulls=false \\
  --logtostderr=true \\
  --pod-manifest-path=/etc/kubernetes/manifests \\
  --v=2
ExecStartPost=/sbin/iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -s 172.17.0.0/12 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -s 192.168.1.0/16 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -p tcp --dport 4194 -j DROP
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
# 2.3 kube-proxy
cat > kube-proxy.service << EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/var/env/env.conf
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/usr/local/bin/kube-proxy \\
  --proxy-mode=iptables \\
  --bind-address=\${NODE_IP} \\
  --hostname-override=\${NODE_IP} \\
  --cluster-cidr=\${SERVICE_CIDR} \\
  --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \\
  --logtostderr=true \\
  --masquerade-all \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
# 2.4 distribute & restart svc
ansible all -m shell -a "systemctl daemon-reload"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $COMPONENT ..."
  ansible all -m copy -a "src=./${COMPONENT}.service dest=/etc/systemd/system"
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart $COMPONENT ..."
  ansible all -m shell -a "systemctl enable $COMPONENT && systemctl restart $COMPONENT"
done
exit
