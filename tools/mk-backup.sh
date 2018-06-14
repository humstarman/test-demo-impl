#!/bin/bash

BAK=/var/k8s/bak
NOW=$(date -d today +'%Y-%m-%d-%H:%M:%S')
ansible master -m shell -a "if [ -d "${BAK}" ]; then mv $BAK ${BAK}-${NOW}; else echo ' - no previous backup found.'; fi"
ansible master -m shell -a "mkdir -p $BAK"
#THIS_DIR=$(cd "$(dirname "$0")";pwd)
TMP=/tmp/k8s/bak
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cp ./*.csv ./info.env passwd.log $TMP
ansible master -m copy -a "src=${TMP}/ dest=${BAK}"
