#!/bin/bash

source log.sh

NAMESPACE=vpclub
echo $NAMESPACE

log "check prerequisites ..."

if [ $(more /etc/redhat-release | grep "CentOS Linux release 7" | wc -l) == 0 ]; then
	log "This installation script is for CentOS 7.x only"
	exit
fi

systemctl stop firewalld
systemctl disable firewalld.service
if [ $(systemctl status firewalld | grep "firewalld.service; disabled;" | wc -l) == 0 ] && [ $(systemctl status firewalld | grep "Active: inactive" | wc -l) == 0 ] ; then
	log "please make sure firewall is disabled, run systemctl status firewalld to check."
	exit
fi

systemctl stop iptables
systemctl disable iptables.service
if [ $(systemctl status iptables | grep "Active: inactive" | wc -l) == 0 ] && [ $(systemctl status iptables | grep "Active: failed" | wc -l) == 0 ]; then
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

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion pyOpenSSL NetworkManager

systemctl enable NetworkManager.service
systemctl start NetworkManager

if [ $(systemctl status NetworkManager | grep "active (running)" | wc -l) == 0 ]; then
	log "please make sure NetworkManager is running."
	exit
fi

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
openshift_release=v1.4.0-alpha.1
#openshift_release=v1.3.1
openshift_image_tag=v1.4.0-alpha.1
openshift_install_examples=true

osm_use_cockpit=true
osm_cockpit_plugins=['cockpit-kubernetes']

containerized=true

openshift_master_default_subdomain=47.89.178.33.nip.io

openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_host=172.22.0.1
openshift_hosted_registry_storage_nfs_directory=/data/nfs
openshift_hosted_registry_storage_volume_name=osv
openshift_hosted_registry_storage_volume_size=20Gi

[masters]
devops.vpclub.cn
 
# host group for etcd
[etcd]
devops.vpclub.cn
 
# host group for nodes, includes region info
[nodes]
devops.vpclub.cn openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
#120.76.22.195 openshift_node_labels="{'region': 'infra', 'zone': 'southcn'}"
EOF

log "iterate servers"

#ANSIBLE_SERVERS=
#cat config/cluster-ip.conf | { while read server; do
#	echo $server
#	IP=$(echo $server | awk '{print $1;}')
#	SERVER_NAME=$(echo $server | awk '{print $2;}')
#	HOST_ITEM="${IP} ${SERVER_NAME}.openshift.${NAMESPACE}.local"
#	echo $HOST_ITEM
#
#	echo "add ${IP} ${SERVER_NAME} to trust list"
#	if [ $(cat /etc/hosts | grep "${HOST_ITEM}" | wc -l) == 0 ]; then
#		echo $HOST_ITEM >> /etc/hosts
#	fi
#
#	ssh-copy-id -i ${HOME}/.ssh/id_rsa.pub ${IP}
#
#	if [ $(echo $SERVER_NAME | grep node | wc -l) == 1 ];
#		log "added node to /etc/ansible/hosts"
#		echo "${SERVER_NAME}.openshift.${NAMESPACE}.local openshift_node_labels=\"{'region': 'primary', 'zone': '$SERVER_NAME'}\"" >> /etc/ansible/hosts
#    fi
#        
#    done
#} 

if [ ! -d ./openshift-ansible ]; then
	git clone https://github.com/openshift/openshift-ansible
fi

ansible all -m ping

#exit

ansible-playbook openshift-ansible/playbooks/byo/config.yml

oadm policy add-cluster-role-to-user cluster-admin admin --config=/etc/origin/master/admin.kubeconfig
oadm manage-node devops.vpclub.cn --schedulable=true
oc new-project dev --display-name="Tasks - Dev"
oc new-project stage --display-name="Tasks - Stage"
oc new-project cicd --display-name="CI/CD"
oc policy add-role-to-user edit system:serviceaccount:cicd:default -n dev
oc policy add-role-to-user edit system:serviceaccount:cicd:default -n stage

oc get nodes

log "Done"

