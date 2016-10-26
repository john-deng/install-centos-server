#!/bin/bash

source log.sh
source clap.sh

echo $CMD_LINE

function remove_docker() {
	log "disable docker service"
	systemctl stop docker
	systemctl disable docker.service

	rm -rf /var/lib/docker
	rm -rf /run/docker.sock

	log "removing docker ..."
	yum list installed | grep docker | awk -v N=1 '{print $N}' | xargs yum -y remove
	log "docker was removed"
}

STORAGE_DEVICE=$storage
if [ "$STORAGE_DEVICE" == "" ]; then
	STORAGE_DEVICE=/dev/sdb
fi	

if [ $(lsblk | grep sdb | wc -l) == 0 ]; then
	log "${STORAGE_DEVICE} is not exist!"
	exit
fi

yes | lvremove /dev/mapper/docker--vg-docker--pool
yes | vgremove docker-vg

if [ $(lvs | grep docker-pool | grep docker-vg | wc -l) == 0 ]; then
log "setup direct disk mode"
echo "-------------------------------------------------------------------------"

fdisk ${STORAGE_DEVICE} <<EOF
d

n
p
1



t
8e

w
EOF

if [ "$all" == "all" ]
	yum -y update
	yum makecache
	remove_docker
	yum -y install docker
fi

pvcreate ${STORAGE_DEVICE}1

vgcreate docker-vg ${STORAGE_DEVICE}1

fi # if [ $(lvs | grep docker-pool | grep docker-vg | wc -l) == 0 ]; then

sed -i '/OPTIONS=.*/c\OPTIONS="--selinux-enabled --insecure-registry 172.30.0.0/16"' /etc/sysconfig/docker

if [ $(cat /etc/sysconfig/docker-storage-setup | grep docker-vg | wc -l) == 0  ]; then

tee /etc/sysconfig/docker-storage-setup <<-'EOF'
VG=docker-vg
SETUP_LVM_THIN_POOL=yes
DATA_SIZE=70%FREE
EOF

fi # if [ $(cat /etc/sysconfig/docker-storage-setup | grep docker-vg | wc -l) == 0  ]; then

log "running docker-storage-setup ..."
systemctl stop docker

rm -rf /var/lib/docker

/usr/bin/docker-storage-setup

lvs

log "reload docker.service"
systemctl daemon-reload

log "enable docker.service"
systemctl enable docker.service

log "start docker.service"
systemctl start docker

if [ "$?" != 0 ]; then
	log "Failed to start docker"
	exit
fi

log "show docker info"
docker info

log "Installed $(docker -v)"

