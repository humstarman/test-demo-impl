#!/bin/bash

# 0 set env
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
MASTER=$(sed s/","/" "/g ./master.csv)
N=$(echo $MASTER | wc -w)
NET_ID=$(cat ./master.csv)
NET_ID=${NET_ID%%,*}
NET_ID=${NET_ID%.*}
TOOLS=${URL}/tools
getScript $TOOLS deal-env.sh
getScript $TOOLS mk-env-conf.sh
getScript $TOOLS put-this-ip.sh
getScript $TOOLS put-node-ip.sh

# 1 mk environment variables
ENV=/var/env
## 1 k8s.env
ansible new -m copy -a "src=$ENV/k8s.env dest=$ENV"
## 2 token.csv
ansible new -m copy -a "src=/etc/kubernetes/token.csv dest=/etc/kubernetes"
## 3 this-ip.env 
ansible new -m script -a "./put-node-ip.sh $NET_ID"
## 4 etcd.env
mkdir -p /tmp/etcd
yes | cp $ENV/etcd.env /tmp/etcd
FILE=/tmp/etcd/etcd.env
sed -i /"^export NODE_NAME="/d $FILE
ansible new -m copy -a "src=$FILE dest=/var/env/etcd.env"



NAME=etcd

IPS=$MASTER

N=$(echo $MASTER | wc | awk -F ' ' '{print $2}')

NODE_IPS=""
ETCD_NODES=""
ETCD_ENDPOINTS=""

for i in $(seq -s ' ' 1 $N); do
  NODE_NAME="${NAME}-${i}"
  IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
  NODE_IPS+=" $IP"
  ETCD_NODES+=",${NODE_NAME}=https://$IP:2380"
  ETCD_ENDPOINTS+=",https://$IP:2379"
done

#echo $NODE_IPS
#echo $ETCD_NODES
NODE_IPS=${NODE_IPS#* }
ETCD_NODES=${ETCD_NODES#*,}
ETCD_ENDPOINTS=${ETCD_ENDPOINTS#*,}
#echo $NODE_IPS
#echo $ETCD_NODES

for i in $(seq -s ' ' 1 $N); do
  FILE="./tmp/etcd.env.${i}"
  [ -e $FILE ] && rm -f $FILE
  [ -e $FILE ] || touch $FILE
  NODE_NAME="${NAME}-${i}"
  IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
  cat > $FILE << EOF
export NODE_NAME=$NODE_NAME
export NODE_IPS="$NODE_IPS"
export ETCD_NODES=$ETCD_NODES
export ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
  ansible $IP -m copy -a "src=$FILE dest=/var/env/etcd.env"
done
rm -rf ./tmp

ansible all -m script -a ./mk-env-conf.sh

cat > ./write-to-etc_profile << EOF
FILES=\$(find /var/env -name "*.env")

if [ -n "\$FILES" ]
then
  for FILE in \$FILES
  do
    [ -f \$FILE ] && source \$FILE
  done
fi
EOF
ansible all -m copy -a "src=./write-to-etc_profile dest=/tmp"
#IF=$(cat /etc/profile | grep 'FILES=$(find \/var\/env -name "\*.env"')
ansible all -m script -a ./deal-env.sh
#fi
#ansible all -m shell -a "rm -f /tmp/write-to-etc_profile"
