#!/bin/bash
set -e
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
getScript () {
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
getScript $TOOLS mk-ansible-hosts.sh
ANSIBLE=/etc/ansible/hosts
CSVS=$(ls | grep -E ".csv$")
if [ -n "$CSVS" ]; then
  for CSV in $CSVS; do
    GROUP=$CSV
    GROUP=${GROUP##*/}
    GROUP=${GROUP%.*}
    ./mk-ansible-hosts.sh -g $GROUP -i $(cat $CSV) -a $ANSIBLE -o
  done
fi
