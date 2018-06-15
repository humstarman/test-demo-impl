#!/bin/bash

# 0 set env
source ./info.env
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
N_ETCD=3
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w)
if [ ! -f ./node.csv ]; then
  NODE_EXISTENCE=false
else
  if [ -z "$(cat ./node.csv)" ]; then
    NODE_EXISTENCE=false
  fi
fi
if $NODE_EXISTENCE; then
  NODE=$(sed s/","/" "/g ./node.csv)
  N_NODE=$(echo $NODE | wc | awk -F ' ' '{print $2}')
fi
NEW=$(sed s/","/" "/g ./new.csv)
N_NEW=$(echo $MASTER | wc -w)
NET_ID=$(cat ./master.csv)
NET_ID=${NET_ID%%,*}
NET_ID=${NET_ID%.*}
TOOLS=${URL}/tools
getScript $TOOLS deal-env.sh
getScript $TOOLS mk-env-conf.sh
getScript $TOOLS put-node-ip.sh

# 1 mk environment variables
ENV=/var/env
## 1 k8s.env
ansible new -m copy -a "src=$ENV/k8s.env dest=$ENV"
## 2 token.csv
ansible new -m copy -a "src=/etc/kubernetes/token.csv dest=/etc/kubernetes"
## 3 this-ip.env 
ansible new -m script -a "./put-this-ip.sh $NET_ID"
## 4 etcd.env
### 1 for a new master, first determine if deploying etcd
### by default, three healthy etcd node is good enough
### if want to set the number of etcd nodes, 
### change the value of N_ETCD in:
### - this scrript 
### - deploy-etcd.sh
N_HEALTHY_ETCD=$(kubectl get componentstatus | grep etcd- | awk -F ' ' '{print $2}' | grep -E "^Healthy$" | wc -l)
if [[ "$N_HEALTHY_ETCD" < "$N_ETCD" ]]; then
  N2DEPLOY=$[${N_ETCD}-${N_HEALTHY_ETCD}]
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - the current number of etcd nodes is ${N_HEALTHY_ETCD}, falling short of expecttion value ${N_ETCD}"
  echo " - $N2DEPLOY more to deploy." 
  # set env
  NAME=etcd
  NODE_IPS=""
  ETCD_NODES=""
  ETCD_ENDPOINTS=""
  # generate csv
  ## for previous master
  IPS=$MASTER
  N=${N_MASTER}
  for i in $(seq -s ' ' 1 $N); do
    IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
    NODE_NAME="${NAME}-${IP}"
    NODE_IPS+=" $IP"
    ETCD_NODES+=",${NODE_NAME}=https://$IP:2380"
    ETCD_ENDPOINTS+=",https://$IP:2379"
  done
  ## for new master 
  IPS=$NEW
  N=${N2DEPLOY}
  for i in $(seq -s ' ' 1 $N); do
    IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
    NODE_NAME="${NAME}-${IP}"
    NODE_IPS+=" $IP"
    ETCD_NODES+=",${NODE_NAME}=https://$IP:2380"
    ETCD_ENDPOINTS+=",https://$IP:2379"
  done
  # distribute environment file
  #echo $NODE_IPS
  #echo $ETCD_NODES
  NODE_IPS=${NODE_IPS#* }
  ETCD_NODES=${ETCD_NODES#*,}
  ETCD_ENDPOINTS=${ETCD_ENDPOINTS#*,}
  #echo $NODE_IPS
  #echo $ETCD_NODES
  ## to previous master
  IPS=$MASTER
  N=${N_MASTER}
  for i in $(seq -s ' ' 1 $N); do
    IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
    FILE="./tmp/etcd.env.${IP}"
    [ -e $FILE ] && rm -f $FILE
    [ -e $FILE ] || touch $FILE
    NODE_NAME="${NAME}-${IP}"
    cat > $FILE << EOF
export NODE_NAME=$NODE_NAME
export NODE_IPS="$NODE_IPS"
export ETCD_NODES=$ETCD_NODES
export ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
    ansible $IP -m copy -a "src=$FILE dest=/var/env/etcd.env"
  done
  ## to new master that deploying etcd
  IPS=$NEW
  N=${N2DEPLOY}
  for i in $(seq -s ' ' 1 $N); do
    IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
    FILE="./tmp/etcd.env.${IP}"
    [ -e $FILE ] && rm -f $FILE
    [ -e $FILE ] || touch $FILE
    NODE_NAME="${NAME}-${IP}"
    cat > $FILE << EOF
export NODE_NAME=$NODE_NAME
export NODE_IPS="$NODE_IPS"
export ETCD_NODES=$ETCD_NODES
export ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
    ansible $IP -m copy -a "src=$FILE dest=/var/env/etcd.env"
  done
  ## to new master that not deploying etcd
  ## and, to node
  FILE="./tmp/etcd.env"
  [ -e $FILE ] && rm -f $FILE
  [ -e $FILE ] || touch $FILE
  cat > $FILE << EOF
export ETCD_NODES=$ETCD_NODES
export ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
  if [[ ! "$[${N2DEPLOY}+1]" > "${N_NEW}" ]]; then
    IPS=$NEW
    N_FROM=$[${N2DEPLOY}+1]
    N_TO=$N_NEW
    for i in $(seq -s ' ' ${N_FROM} ${N_TO}); do
      IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
      ansible $IP -m copy -a "src=$FILE dest=/var/env/etcd.env"
    done
  fi
  if $NODE_EXISTENCE; then
    ansible node -m copy -a "src=$FILE dest=/var/env/etcd.env"
  fi
  rm -rf ./tmp
  ansible all -m script -a ./mk-env-conf.sh
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - the current number of etcd nodes is ${N_HEALTHY_ETCD}, meeting expecttion value ${N_ETCD}"
  echo " - no need to deploy new etcd node."
  mkdir -p /tmp/etcd
  yes | cp $ENV/etcd.env /tmp/etcd
  FILE=/tmp/etcd/etcd.env
  sed -i /"^export NODE_NAME="/d $FILE
  ansible new -m copy -a "src=$FILE dest=/var/env/etcd.env"
  ## env.conf
  ansible new -m script -a ./mk-env-conf.sh
fi

# 2 write /etc/profile
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
ansible new -m copy -a "src=./write-to-etc_profile dest=/tmp"
ansible new -m script -a ./deal-env.sh
exit 0
