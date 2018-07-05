#!/bin/bash
set -e
show_help () {
cat << USAGE
usage: $0 [ -n NET-ID ] [ -v VIRTUAL-IP ]
    -n : Specify the network ID. 
    -v : Specify the virtual IP address.
    -p : Specify the port used by the virtual Kubernetes master server.
         if not specified, use '443' for default. 
USAGE
exit 0
}
# Get Opts
while getopts "hn:v:p:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    n)  NET_ID=$OPTARG # 参数存在$OPTARG中
        ;;
    v)  VIP=$OPTARG
        ;;
    p)  PORT=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
[ -z "$*" ] && show_help
chk_var () {
if [ -z "$2" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no input for \"$1\", try \"$0 -h\"."
  sleep 3
  exit 1
fi
}
chk_var -n $NET_ID
chk_var -v $VIP
THIS_IP=$NET_ID
IPS=$(ip addr | grep inet | awk -F 'inet ' '{print $2}' | awk -F '/' '{print $1}')
SUFFIX=$(echo ${IPS#*${NET_ID}} | awk -F ' ' '{print $1}')
THIS_IP+=${SUFFIX}
MASTER_IP=$VIP
PORT=${PORT:-"443"}
[ -e /var/env ] || mkdir -p /var/env
[ -f /var/env/this-ip.env ] || touch /var/env/this-ip.env
THIS_IP=$(echo "$THIS_IP" | grep -E "^[0-9]*.[0-9]*.[0-9]*.[0-9]*$")
if [ -n "$THIS_IP" ]; then
  cat > /var/env/this-ip.env << EOF
export NET_ID=$NET_ID
export THIS_IP=$THIS_IP
export NODE_IP=$THIS_IP
export MASTER_IP=$MASTER_IP
export VIP=$VIP
export KUBE_APISERVER=https://${MASTER_IP}:${PORT}
EOF
else
  echo -e " - check the value of net ID: $NET_ID" | tee /var/env/this-ip.env
fi
