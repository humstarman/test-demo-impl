#!/bin/bash

set -e

# 0 set env 
NEEDS="master.csv node.csv info.env passwd.log"
N_NEED=$(echo $NEEDS | wc -w)
BAK_DIR=/var/k8s/bak
function getBackup(){
  BAK_DIR=${1:-"/var/k8s/bak"}
  yes | cp -r $BAK_DIR/* ./
}

# check files 
i=0
for NEED in $NEEDS; do
  if [ -z "$(ls | grep -E "^${NEED}$")" ]; then
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - missing ${NEED}" 
  else
    i=$[$i+1]
  fi
done
if [[ "$N_NEED" != "$i" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - missing files, backup now ..." 
  getBackup
fi
i=0
for NEED in $NEEDS; do
  if [ -z "$(ls | grep -E "^${NEED}$")" ]; then
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - missing ${NEED}" 
  else
    i=$[$i+1]
  fi
done
if [[ "$N_NEED" != "$i" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - missing files !!!" 
  echo " - all files below are needed:"
  echo ""
  for NEED in $NEEDS; do
    echo " - $NEED"
  done
  echo ""
  echo " - please check."
  sleep 3 
  exit 1
fi
exit 0
