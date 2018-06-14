#!/bin/bash
set -e
if [ ! -x "$(command -v kubectl)" ]; then
   echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no kubectl installed!"
   echo " - maybe an incomplete installation of Kubernetes."
   echo " - please check!"
   sleep 3
   exit 1
fi
if ! kubectl get node; then
   echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - failed, when using kubectl to get nodes!"
   echo " - please check!"
   sleep 3
   exit 1
fi
if [[ "$(kubectl get node | wc -l)" > "1" ]]; then
   echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes cluster checked!"
else
   echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no node found in cluster!"
   echo " - please check!"
   sleep 3
   exit 1
fi
if kubectl get node | grep NotReady; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - NotReady status node found !!!"
  echo " - please check."
  sleep 3
  exit 1
fi
exit 0
