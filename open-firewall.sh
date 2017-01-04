#!/bin/bash

source log.sh
source clap.sh

if [ "$port" == "" ]; then
  log 'please specify port, e.g. $0 port=52055'
  exit
fi


iptables -A INPUT -p tcp --dport $port -j ACCEPT
iptables -A OUTPUT -p tcp --dport $port -j ACCEPT

systemctl unmask firewalld
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --zone=public --add-port=$port/tcp --permanent
firewall-cmd --reload
