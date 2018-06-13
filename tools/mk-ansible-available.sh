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
TOOLS=$URL/tools
function getScript(){
  TRY=10
  URL=$1
  SCRIPT=$2
  for i in $(seq -s " " 1 ${TRY}); do
    curl -s -o ./$SCRIPT $URL/$SCRIPT
    if cat ./$SCRIPT | grep "404: Not Found"; then
      rm -f ./$SCRIPT
    else
      break
    fi
  done
  if [ -f "./$SCRIPT" ]; then
    chmod +x ./$SCRIPT
  else
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - downloading failed !!!" 
    echo " - $URL/$SCRIPT"
    echo " - Please check !!!"
    sleep 3
    exit 1
  fi
}

# config /etc/ansible/hosts
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - config /etc/ansible/hosts."
#cat > /etc/ansible/hosts << EOF
ANSIBLE=/etc/ansible/hosts
[ -f "$ANSIBLE" ] && rm -f $ANSIBLE
[ -f "$ANSIBLE" ] || touch $ANSIBLE
CSVS=$(ls | grep -E ".csv$")
for CSV in $CSVS; do
  GROUP=$CSV
  GROUP=${GROUP##*/}
  GROUP=${GROUP%.*}
  cat >> $ANSIBLE << EOF 
[$GROUP]
EOF
  MEMBERS=$(sed s/","/" "/g $CSV)
  for MEMBER in $MEMBERS; do
    echo $MEMBER >> $ANSIBLE
  done
  echo "" >> $ANSIBLE
done
if false; then
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
fi
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - /etc/ansible/hosts configured."
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - check connectivity amongst hosts ..."
getScript $TOOLS auto-cp-ssh-id.sh
getScript $TOOLS mk-ssh-conn.sh
getScript $TOOLS check-python.sh
if [[ -f ./passwd.log && -n "$(cat ./passwd.log)" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - as ./passwd.log existed, automated make ssh connectivity."
  ./mk-ssh-conn.sh $(cat ./passwd.log)
  ./check-python.sh
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
    getScript $URL/tools auto-cp-ssh-id.sh
    getScript $URL/tools mk-ssh-conn.sh
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
