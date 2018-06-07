#!/bin/bash

DIRS="/etc/kubernetes/ssl /etc/flanneld/ssl /etc/etcd/ssl ./ssl"
for DIR in $DIRS; do
  [[ -d "$DIR" && '/' != "$DIR" ]] && rm -rf $DIR/* && \
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - clear $DIR ... "
done
