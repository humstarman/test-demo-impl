#!/bin/bash

set -e

if [ ! -f ./new.csv ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no info about new node(s) found, failed to re-set env."
  sleep 3
  exit 1
fi

source info.env

# mk node.csv
if [[ -f ./node.csv && -n "$(cat ./node.csv)" ]]; then
  # nodes existed 
  NODE=$(cat ./node.csv)
  NODE+=','
  NODE+=$(cat ./new.csv)
  echo $NODE > ./node.csv
else
  yes | cp new.csv node.csv
fi
rm -f ./new.csv

# generate info.env
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w) 
NODE=$(sed s/","/" "/g ./node.csv)
N_NODE=$(echo $NODE | wc -w)
NODE_EXISTENCE=true
FILE=info.env
cat > $FILE << EOF
export MASTER="$MASTER"
export N_MASTER=$N_MASTER
export NODE_EXISTENCE=$NODE_EXISTENCE
export NODE="$NODE"
export N_NODE=$N_NODE
export URL=$URL
EOF

