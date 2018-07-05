#!/bin/bash
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
MASTERS="$(cat ./master.csv | tr ',' ' ')"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - masters: $(echo $MASTERS)"
CHK=${CHK:-"chk.sh"}
VPORT=$KUBE_APISERVER
VPORT=${VPORT##*':'}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - virtual kube master server: https://${VIP}:${VPORT}"
# 1 install vip
FILE=/tmp/install-vip.sh
cat > $FILE <<"EOF"
#!/bin/bash
if [ -x "$(command -v yum)" ]; then
  yum makecache fast
  yum install -y haproxy keepalived
fi
if [ -x "$(command -v apt-get)" ]; then
  apt-get update
  apt-get install -y haproxy keepalived
fi
MODS=" \
net.ipv4.ip_forward^=^1 \
net.ipv4.ip_nonlocal_bind^=^1 \
net.ipv4.conf.lo.arp_ignore^=^1 \
net.ipv4.conf.lo.arp_announce^=^2 \
net.ipv4.conf.all.arp_ignore^=^1 \
net.ipv4.conf.all.arp_announce^=^2"
FILE=/etc/sysctl.conf
[ -f $FILE ] || touch $FILE
for MOD in $MODS; do
  MOD=$(echo $MOD | tr "^" " ")
  if ! cat $FILE | grep "$MOD"; then
    echo $MOD >> $FILE
  fi
done
sysctl -p 
EOF
ansible master -m script -a $FILE 
# 2 vip-mode
FILE="vip-mode"
BIN="${FILE}.sh"
SVC="${FILE}.service"
cat > /tmp/${BIN} << "EOF"
#!/bin/bash
ipvs_modules="ip_vs"
for kernel_module in ${ipvs_modules}; do
  /sbin/modprobe ${kernel_module}
done
lsmod | grep ip_vs
MODS=" \
net.ipv4.ip_forward^=^1 \
net.ipv4.ip_nonlocal_bind^=^1 \
net.ipv4.conf.lo.arp_ignore^=^1 \
net.ipv4.conf.lo.arp_announce^=^2 \
net.ipv4.conf.all.arp_ignore^=^1 \
net.ipv4.conf.all.arp_announce^=^2"
FILE=/etc/sysctl.conf
[ -f $FILE ] || touch $FILE
for MOD in $MODS; do
  MOD=$(echo $MOD | tr "^" " ")
  if ! cat $FILE | grep "$MOD"; then
    echo $MOD >> $FILE
  fi
done
sysctl -p
EOF
chmod +x /tmp/${BIN}
cat > /tmp/${SVC} << EOF
[Unit]
Description=Switch-on Kernel Modules Needed by IPVS 

[Service]
Type=oneshot
ExecStart=/usr/local/bin/${BIN}

[Install]
WantedBy=multi-user.target
EOF
ansible master -m copy -a "src=/tmp/${BIN} dest=/usr/local/bin mode='a+x'"
ansible master -m copy -a "src=/tmp/${SVC} dest=/etc/systemd/system"
ansible master -m shell -a "systemctl daemon-reload"
ansible master -m shell -a "systemctl enable ${SVC}"
ansible master -m shell -a "systemctl restart ${SVC}"
# haproxy.cfg
FILE=/tmp/haproxy.cfg
cat > $FILE <<EOF
listen stats
  bind    *:9000
  mode    http
  stats   enable
  stats   hide-version
  stats   uri       /stats
  stats   refresh   30s
  stats   realm     Haproxy\ Statistics
  stats   auth      haproxy:haproxy

frontend k8s-api
    bind 0.0.0.0:${VPORT}
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    default_backend k8s-api

backend k8s-api
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
EOF
i=1
for MASTER in $MASTERS; do
  cat >> $FILE <<EOF
    server k8s-api-${i} ${MASTER}:6443 check
EOF
  i=$[i+1]
done
cat >> $FILE <<EOF

frontend k8s-http-api
    bind 0.0.0.0:80
    mode tcp
    option tcplog
    default_backend k8s-http-api

backend k8s-http-api
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
EOF
i=1
for MASTER in $MASTERS; do
  cat >> $FILE <<EOF
    server k8s-http-api-${i} ${MASTER}:8080 check
EOF
  i=$[i+1]
done
ansible master -m copy -a "src=$FILE dest=/etc/haproxy"
# keepalived.conf
FILE=/tmp/keepalived.conf
i=1
for MASTER in $MASTERS; do
  cat > $FILE <<EOF
! Configuration File for keepalived
#{{.ip}} $MASTER

global_defs {
   notification_email {
   }
   router_id kube_api_7
}

vrrp_script check_haproxy {
    # 自身状态检测
    script "/etc/keepalived/${CHK}"
    interval 3
    weight 5
}

vrrp_instance haproxy-vip {
    # 使用单播通信，默认是组播通信
    unicast_src_ip $MASTER 
    unicast_peer {
EOF
  for j in $MASTERS; do
    if [[ "$j" != "${MASTER}" ]]; then
      cat >> $FILE <<EOF
        $j
EOF
    fi
  done
  cat >> $FILE <<EOF
    }
    # 初始化状态
EOF
  if [[ "$i" == "1" ]]; then
    cat >> $FILE <<EOF
    state MASTER
EOF
  else
    cat >> $FILE <<EOF
    state BACKUP
EOF
  fi
  #INTERFACE=$(ip addr | grep $MASTER)
  #INTERFACE=${INTERFACE##*"scope global "}
  cat >> $FILE <<EOF
    # 虚拟ip 绑定的网卡 （这里根据你自己的实际情况选择网卡）
    interface {{.interface}} 
    #use_vmac
    # 此ID要配置一致
    virtual_router_id 51
    # 默认启动优先级，Master要比Backup大点，但要控制量，保证自身状态检测生效
EOF
  if [[ "$i" == "1" ]]; then
    cat >> $FILE <<EOF
    priority 101 
EOF
  else
    cat >> $FILE <<EOF
    priority 99
EOF
  fi
  cat >> $FILE <<EOF
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        # 虚拟ip 地址
        $VIP 
    }
    track_script {
        check_haproxy
    }
}
EOF
  i=$[i+1]
  ansible $MASTER -m copy -a "src=$FILE dest=/etc/keepalived"
done
BIN=/tmp/ch-interface.sh
cat > $BIN <<"EOF"
#!/bin/bash
FILE=/etc/keepalived/keepalived.conf
IP=$(cat $FILE | grep {{.ip}})
IP=${IP##*"{{.ip}} "}
INTERFACE=$(ip addr | grep $IP)
INTERFACE=${INTERFACE##*" "}
sed -i s/"{{.interface}}"/"${INTERFACE}"/g $FILE
EOF
chmod +x $BIN
ansible master -m script -a $BIN
# chk
FILE=/tmp/${CHK}
cat > $FILE <<"EOF"
#!/bin/bash
flag=$(systemctl status haproxy &> /dev/null;echo $?)
if [[ $flag != 0 ]]; then
  echo "haproxy is down,close the keepalived"
  systemctl stop keepalived
  exit 1
fi
exit 0
EOF
chmod +x $FILE
ansible master -m copy -a "src=$FILE dest=/etc/keepalived mode='a+x'"
ansible master -m shell -a "systemctl daemon-reload"
ansible master -m shell -a "systemctl enable haproxy" 
ansible master -m shell -a "systemctl restart haproxy" 
ansible master -m shell -a "systemctl enable keepalived" 
ansible master -m shell -a "systemctl restart keepalived" 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - HA deployed."
