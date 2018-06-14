#!/bin/bash
set -e
# 0 set env 
BAK_DIR=/var/k8s/bak
function getBackup(){
  BAK_DIR=${1:-"/var/k8s/bak"}
  yes | cp -r $BAK_DIR/* ./
}
# 1 restore from backup
if [ -d "$BAK_DIR" ]; then
  getBackup $BAK_DIR
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no $BAK_DIR found !!!"
  sleep 3
  exit 1
fi
exit 0
