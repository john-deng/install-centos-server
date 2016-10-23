#!/bin/bash

source log.sh

cat <<EOF > /etc/yum.repos.d/k8s.repo
[kubelet]
name=kubelet
baseurl=http://files.rm-rf.ca/rpms/kubelet/
enabled=1
gpgcheck=0
EOF

yum -y install kubelet kubeadm kubectl kubernetes-cni
systemctl enable kubelet && systemctl start kubelet

if [ "$1" == "master" ]; then
	kubeadm init --use-kubernetes-version v1.4.0
fi
