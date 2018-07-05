#!/bin/bash
show_help () {
cat << USAGE
usage: $0 [ -i INSTALL-DOCKER-OR-NOT ] [ -d DOCKER-DATA-ROOT ] 
    -i : Specify to install Docker or not. If not specified, use 'false' for default.
    -d : Specify the 'data-root' for Docker. If not specified, use '/var/lib/docker' for default.
USAGE
exit 0
}
# Get Opts
while getopts "hi:p:g:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    i)  INSTALL=$OPTARG # 参数存在$OPTARG中
        ;;
    d)  DOCKER=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
INSTALL=${INSTALL:-"false"}
DOCKER=${INSTALL:-"/var/lib/docker"}
[ -d "$DOCKER" ] || mkdir -p $DOCKER
if [ -x "$(command -v yum)" ]; then
  yum makecache
  yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2
  if $INSTALL; then
    yum-config-manager \
      --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce
  fi
  yum install -y conntrack
  FIREWALL="firewalld"
elif [ -x "$(command -v apt-get)" ]; then
  apt-get update
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
  if $INSTALL; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"
    apt-get update
    apt-get install -y docker-ce
  fi
  apt-get install -y conntrack
  FIREWALL="ufw"
else
  echo "$(date) - $0 - [ERROR] - unknown Distributor ID."
  exit 1
fi
systemctl stop $FIREWALL
systemctl disable $FIREWALL
iptables -P FORWARD ACCEPT
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
# mk docker-iptables.service
#cp docker-iptables.service /etc/systemd/system
cat > /etc/systemd/system/docker-iptables.service <<"EOF"
[Unit]
Description=Make Iptables Rules for Docker

[Service]
Type=oneshot
ExecStart=/bin/sh \
          -c \
          "sleep 60 && /sbin/iptables -P FORWARD ACCEPT"

[Install]
WantedBy=multi-user.target
EOF
[ -d /etc/docker ] || mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "data-root": "$DOCKER",
  "registry-mirrors" : [
    "https://nmp34hlf.mirror.aliyuncs.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "insecure-registries" : [
    "192.168.0.0/16",
    "172.0.0.0/8",
    "10.0.0.0/8"
  ],
  "debug" : true,
  "experimental" : true,
  "max-concurrent-downloads" : 10
}
EOF
systemctl daemon-reload
systemctl enable docker
systemctl restart docker
systemctl enable docker-iptables.service
