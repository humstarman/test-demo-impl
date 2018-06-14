#!/bin/bash
set -e
# 0 set env 
NEEDS="master.csv node.csv info.env passwd.log"
N_NEED=$(echo $NEEDS | wc -w)
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
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - missing files !!!" 
  echo " - may cause by broken backup, please check /var/k8s/bak (by default)."
  echo " - or, generate needed files, manually:"
  for NEED in $NEEDS; do
    echo " - $NEED"
  done
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - all needed files found." 
fi
exit 0
