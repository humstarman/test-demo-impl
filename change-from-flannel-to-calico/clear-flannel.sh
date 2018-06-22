#!/bin/bash
# 1 stop & disable flannel
ansible all -m shell -a "systemctl disable flanneld"
ansible all -m shell -a "systemctl stop flanneld"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - stop & disable flannel."
# 2 del flannel bridge
ansible all -m shell -a "ifconfig flannel.1 down"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - delete flannel bridge."
exit 0
