#!/bin/bash

source log.sh

NAMESPACE=$1
if [ "$NAMESPACE" == "" ]; then
	NAMESPACE=vpclub
fi
export NAMESPACE

log "check prerequisites ..."

if [ $(more /etc/redhat-release | grep "CentOS Linux release 7" | wc -l) == 0 ]; then
	log "This installation script is for CentOS 7.x only"
	exit
fi

if [ $(systemctl status firewalld | grep "firewalld.service; disabled;" | wc -l) == 0 ]; then
	log "please make sure firewall is disabled, run systemctl status firewalld to check."
	exit
fi

if [ $(systemctl status iptables | grep "Active: inactive (dead)" | wc -l) == 0 ]; then
	log "please disabled iptables first"
	exit
fi

if [ $(cat /etc/selinux/config | grep "SELINUX=enforcing" | wc -l) == 0 ]; then
	log "please make sure selinux is set to enforcing, check /etc/selinux/config"
	exit
fi

if [ $(getenforce | grep "Enforcing" | wc -l) == 0 ]; then
	log "please make sure selinux is set to enforcing, check /etc/selinux/config"
	exit
fi

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion

yum -y install NetworkManager

if [ $(systemctl status NetworkManager | grep "active (running)" | wc -l) == 0 ]; then
	log "please make sure NetworkManager is running."
	exit
fi

yum -y install pyOpenSSL
rm -rf /etc/ansible/hosts

tee /etc/ansible/hosts <<-'EOF'
# Create an OSEv3 group that contains the masters, nodes, and etcd groups
[OSEv3:children]
masters
nodes
etcd
 
# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=root
deployment_type=origin
 
[masters]
master.openshift.${NAMESPACE}.local
 
# host group for etcd
[etcd]
etcd.openshift.${NAMESPACE}.local
 
# host group for nodes, includes region info
[nodes]
master.openshift.${NAMESPACE}.local openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
EOF

ANSIBLE_SERVERS=
cat config/cluster-ip.conf | awk '{print $1;}' | { while read server; do
	IP=$(echo $server | awk '{print $1;}')
	SERVER_NAME=$(echo $server | awk '{print $2;}')
	HOST_ITEM="${IP} ${SERVER_NAME}.openshift.${NAMESPACE}.local"


	echo "add ${IP} ${SERVER_NAME} to trust list"
	if [ $(cat /etc/hosts | grep "${HOST_ITEM}" | wc -l) == 0 ]; then
		echo $HOST_ITEM >> /etc/hosts
	fi

	ssh-copy-id -i ~/.ssh/id_rsa.pub $ip

	echo "${ANSIBLE_SERVERS}\n${SERVER_NAME}.openshift.${NAMESPACE}.local openshift_node_labels=\"{'region': 'primary', 'zone': '$SERVER_NAME'}\"" >> /etc/ansible/hosts
        
    done
} 

if [ ! -d ./openshift-ansible ]; then
	proxychains4 git clone https://github.com/openshift/openshift-ansible
fi

ansible all -m ping

ansible-playbook openshift-ansible/playbooks/byo/config.yml

oc get nodes

log "Done"
