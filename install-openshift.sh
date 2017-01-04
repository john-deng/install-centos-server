#!/bin/bash

source log.sh
source clap.sh

if [ "$namespace" == "" ]; then
        namespace=vpclub
fi

if [ "$master" == "" ]; then
	master=devops.vpclub.cn
fi


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

# ssh-copy-id -i ${HOME}/.ssh/id_rsa.pub ${IP}

if [ ! -d ./openshift-ansible ]; then
	git clone https://github.com/openshift/openshift-ansible
fi

ansible all -m ping
ansible-playbook -v openshift-ansible/playbooks/byo/config.yml

oadm policy add-cluster-role-to-user cluster-admin admin --config=/etc/origin/master/admin.kubeconfig
oadm manage-node $master --schedulable=true
oc new-project dev --display-name="Tasks - Dev"
oc new-project stage --display-name="Tasks - Stage"
oc new-project cicd --display-name="CI/CD"
oc policy add-role-to-user edit system:serviceaccount:cicd:default -n cicd
oc policy add-role-to-user edit system:serviceaccount:cicd:default -n dev
oc policy add-role-to-user edit system:serviceaccount:cicd:default -n stage

oc policy add-role-to-user edit system:serviceaccount:cicd:dev -n cicd
oc policy add-role-to-user edit system:serviceaccount:cicd:stage -n cicd


oc get nodes

log "Done"

