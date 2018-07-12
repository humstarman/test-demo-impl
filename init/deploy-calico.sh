#!/bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - install calico ..."
# 0 set env
:(){
  FILES=$(find /var/env -name "*.env")
  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:
source info.env
MANIFEST=${URL}/manifest
# 1 download 
BASE_PATH=calico
mkdir -p ${BASE_PATH}  
cd ${BASE_PATH} && \
  curl -s -O ${MANIFEST}/${BASE_PATH}/Makefile.sed && \
  cd -
MANIFEST_PATH=calico/manifest
mkdir -p ${MANIFEST_PATH}
cd ${MANIFEST_PATH} && \
  curl -s -O ${MANIFEST}/${MANIFEST_PATH}/calicoctl.cfg.sed && \
  curl -s -O ${MANIFEST}/${MANIFEST_PATH}/calico.yaml.sed && \
  curl -s -O ${MANIFEST}/${MANIFEST_PATH}/rbac.yaml.sed && \
  cd -
# 2 sed
cd ${BASE_PATH} && \
  cp Makefile.sed Makefile && \
  sed -i s?"{{.env.cluster.cidr}}"?"${CLUSTER_CIDR}"?g Makefile && \
  cd - 
# 3 make
cd ${BASE_PATH} && \
  make all && \
  cd - 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - calico installed."
