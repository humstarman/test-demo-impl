#!/bin/bash

set -e

# 0 set env 
NEEDS="new.csv"
N_NEED=$(echo $NEEDS | wc -w)

# check files 
i=0
for NEED in $NEEDS; do
  if [ -z "$(ls | grep -E "^${NEED}$")" ]; then
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - missing ${NEED}" 
  else
    i=$[$i+1]
  fi
done
if [[ "$N_NEED" != "$i" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - missing files !!!" 
  exit 1
fi
exit 0
