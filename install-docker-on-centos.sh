#!/bin/bash

function log() {
	echo "[LINE: ${BASH_LINENO[*]}] $1"
}

function remove_docker() {
	log "removing docker ..."
	yum list installed | grep docker | awk -v N=1 '{print $N}' | xargs yum -y remove
	log "docker was removed"
}

STORAGE_DEVICE=$1
if [ "$STORAGE_DEVICE" == "" ]; then
	STORAGE_DEVICE=/dev/sdb
fi	

if [ $(lsblk | grep sdb | wc -l) == 0 ]; then
	log "${STORAGE_DEVICE} is not exist!"
	exit
fi

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

remove_docker
yum -y install docker

pvcreate ${STORAGE_DEVICE}1

vgcreate docker-vg ${STORAGE_DEVICE}1

if [ $(cat /etc/sysconfig/docker-storage-setup | grep docker-vg | wc -l) == 0  ]; then

tee /etc/sysconfig/docker-storage-setup <<-'EOF'
VG=docker-vg
SETUP_LVM_THIN_POOL=yes
DATA_SIZE=70%FREE
EOF

fi

systemctl stop docker

rm -rf /var/lib/docker

/usr/bin/docker-storage-setup

lvs

fi # if [ $(lvs | grep docker-pool | grep docker-vg | wc -l) == 0 ]; then

log "reinstall docker-engine ..."
echo "-------------------------------------------------------------------------"

if [ $(cat /etc/yum.repos.d/docker.repo | grep tsinghua | wc -l ) == 0 ]; then

tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/docker/yum/repo/centos7
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/docker/yum/gpg
EOF

fi

remove_docker

systemctl stop docker
systemctl disable docker.service

log "installing docker ... "
yum -y update
yum makecache
yum -y install docker-engine

log "replacing docker.service"
cp docker.service /usr/lib/systemd/system/
cp docker-storage /etc/sysconfig/

log "reload docker.service"
systemctl daemon-reload

log "enable docker.service"
systemctl enable docker.service

log "start docker.service"
systemctl start docker

log "show docker info"
docker info
