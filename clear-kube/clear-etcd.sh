#!/bin/bash
# stop svc
systemctl stop etcd
# clear files
# 删除 etcd 的工作目录和数据目录
rm -rf /var/lib/etcd
# 删除 systemd unit 文件
rm -rf /etc/systemd/system/etcd.service
# 删除程序文件
rm -rf /usr/local/bin/etcd
# 删除 TLS 证书文件
rm -rf /etc/etcd/ssl/*
