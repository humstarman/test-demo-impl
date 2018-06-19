#!/bin/bash

set -e

if [ ! -f ./new.csv ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no info about new node(s) found, failed to re-set env."
  sleep 3
  exit 1
fi

source info.env

# mk master.csv
MASTER=$(cat ./master.csv)
MASTER+=","
MASTER+=$(cat ./new.csv)
rm -f ./new.csv
echo $MASTER > ./master.csv

# generate info.env
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w) 
NODE_EXISTENCE=true
if [ ! -f ./node.csv ]; then
  NODE_EXISTENCE=false
else
  if [ -z "$(cat ./node.csv)" ]; then
    NODE_EXISTENCE=false
  fi
fi
if $NODE_EXISTENCE; then
  NODE=$(sed s/","/" "/g ./node.csv)
  N_NODE=$(echo $NODE | wc -w)
fi
FILE=info.env
cat > $FILE << EOF
export MASTER="$MASTER"
export N_MASTER=$N_MASTER
export NODE_EXISTENCE=$NODE_EXISTENCE
export NODE="$NODE"
export N_NODE=$N_NODE
export URL=$URL
EOF
