#!/bin/bash

FILE=info.env
if [ -f ./$FILE ]; then
  source ./$FILE
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no environment file found!" 
  echo " - exit!"
  sleep 3
  exit 1
fi
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}

# config /etc/ansible/hosts
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - config /etc/ansible/hosts."
#cat > /etc/ansible/hosts << EOF
ANSIBLE=/etc/ansible/hosts
echo "[master]" > $ANSIBLE
for ip in $MASTER; do
  echo $ip >> $ANSIBLE
done
if $NODE_EXISTENCE; then
  echo "[node]" >> $ANSIBLE
  for ip in $NODE; do
    echo $ip >> $ANSIBLE
  done
fi
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - /etc/ansible/hosts configured."
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - check connectivity amongst hosts ..."
getScript $URL auto-cp-ssh-id.sh
getScript $URL mk-ssh-conn.sh
if [[ -f ./passwd.log && -n "$(cat ./passwd.log)" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - as ./passwd.log existed, automated make ssh connectivity."
  ./mk-ssh-conn.sh $(cat ./passwd.log)
  for ip in $MASTER; do
    ssh -t root@$ip "if [ ! -x "$(command -v python)" ]; then if [ -x "$(command -v yum)" ]; then yum install -y python; fi; if [ -x "$(command -v apt-get)" ]; then apt-get install -y python; fi; fi"
  done
  if $NODE_EXISTENCE; then
    NODE=$(sed s/","/" "/g ./node.csv)
    for ip in $NODE; do
      ssh -t root@$ip "if [ ! -x "$(command -v python)" ]; then if [ -x "$(command -v yum)" ]; then yum install -y python; fi; if [ -x "$(command -v apt-get)" ]; then apt-get install -y python; fi; fi"
    done
  fi
fi
if ! ansible all -m ping; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - connectivity checking failed."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - you should make ssh connectivity without password from this host to all the other hosts,"
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - and install python."
  echo "=== you can use the script mk-ssh-conn.sh in this directoryi, as:"
  echo "=== ./mk-ssh-conn.sh {PASSWORD}"
  exit 1
fi
if false; then
  while ! yes "\n" | ansible all -m ping; do
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - connectivity checking failed."
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - you should make ssh connectivity without password from this host to all the other hosts."
    # fix ssh 
    getScript $URL auto-cp-ssh-id.sh
    getScript $URL mk-ssh-conn.sh
    if [[ -f ./passwd.log && -n "$(cat ./passwd.log)" ]]; then
      echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - as ./passwd.log existed, automated make ssh connectivity."
      ./mk-ssh-conn.sh $(cat ./passwd.log)
      # fix python 
      for ip in $MASTER; do
        ssh -t root@$ip "if [ ! -x "$(command -v python)" ]; then if [ -x "$(command -v yum)" ]; then yum install -y python; fi; if [ -x "$(command -v apt-get)" ]; then apt-get install -y python; fi; fi "
      done
      if $NODE_EXISTENCE; then
        NODE=$(sed s/","/" "/g ./node.csv)
        for ip in $NODE; do
          ssh -t root@$ip "if [ ! -x "$(command -v python)" ]; then if [ -x "$(command -v yum)" ]; then yum install -y python; fi; if [ -x "$(command -v apt-get)" ]; then apt-get install -y python; fi; fi "
        done
      fi
    else
      echo "=== you can use the script mk-ssh-conn.sh in this directoryi, as:."
      echo "=== ./mk-ssh-conn.sh {PASSWORD}"
      exit 1
    fi
  done
fi
