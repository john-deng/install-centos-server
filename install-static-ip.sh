#!/bin/bash

source log.sh


IP=$1
if [ "${IP}" != "" ]; then
	log "setting static ip address"
	sed -i s/.50/.${IP}/g /etc/sysconfig/network-scripts/ifcfg-en*
	systemctl restart network.service
fi
