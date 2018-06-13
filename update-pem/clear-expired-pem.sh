#!/bin/bash

DIRS="/etc/kubernetes/ssl /etc/flanneld/ssl /etc/etcd/ssl ./ssl"
for DIR in $DIRS; do
  if [[ -d "$DIR" && '/' != "$DIR" ]]; then
    rm -rf $DIR/*
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - clear $DIR"
  fi
done
