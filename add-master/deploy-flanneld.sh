#!/bin/bash

set -e
:(){
  FILES=$(find /var/env -name "*.env")
  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:

# 1 cp flannel component 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp flannel component... "
BIN=/usr/local/bin
TMP=/tmp/flannel-component
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $BIN && \
  yes | cp flanneld mk-docker-opts.sh $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=$BIN mode='a+x'"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - flannel components distributed."

# 2 cp flannel pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cp flannel pem ... "
TMP=/tmp/flannel-ssl
SSL=/etc/flanneld/ssl
[ -d "$TMP" ] && rm -rf $TMP
mkdir -p $TMP
cd $SSL && \
  yes | cp flanneld-key.pem flanneld.pem $TMP && \
  cd -
ansible new -m copy -a "src=${TMP}/ dest=$SSL"

# 3 cp flannel systemd unit
SYSTEMD=/etc/systemd/system
FILE=flanneld.service
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
ansible new -m copy -a "src=${SYSTEMD}/$FILE dest=${SYSTEMD}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
ansible new -m shell -a "systemctl daemon-reload"
ansible new -m shell -a "systemctl enable $FILE"
ansible new -m shell -a "systemctl restart $FILE"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $FILE deployed."
