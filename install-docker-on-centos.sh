#!/bin/bash

source "log.sh"
source "clap.sh"
source "format-disk.sh"

echo $CMD_LINE

if [ "$percentage" == "" ]; then
  percentage=95
fi

function remove_docker() {
  log "disable docker service"
  systemctl stop docker
  systemctl disable docker.service

  find /dev/mapper/ -name "*docker*" | xargs lvremove -v -f
  vgremove -f docker
  pvremove -f ${storage}${partition}

  rm -rf /var/lib/docker
  rm -rf /run/docker*
  rm -rf /var/run/docker

  log "removing docker ..."
  yum list installed | grep docker | awk -v N=1 '{print $N}' | xargs yum -y remove
  log "docker was removed"
}


function add_docker_repo() {

  if [ $(cat /etc/yum.repos.d/docker.repo | grep "mirrors.tuna.tsinghua.edu.cn" | wc -l) == 0 ]; then

  cat > /etc/yum.repos.d/docker.repo <<_EOF_

[dockerrepo]
name=Docker Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/docker/yum/repo/centos7
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/docker/yum/gpg

_EOF_

  fi
}

function setup_docker_storage() {

if [ $(cat /etc/sysconfig/docker-storage-setup | grep "VG=docker" | wc -l) == 0  ]; then

  cat > /etc/sysconfig/docker-storage-setup <<_EOF_
VG=docker
SETUP_LVM_THIN_POOL=yes
DATA_SIZE=${percentage}%FREE

_EOF_

fi # if [ $(cat /etc/sysconfig/docker-storage-setup | grep docker | wc -l) == 0  ]; then


}


function config_docker_options() {

mkdir -p /etc/systemd/system/docker.service.d/

if [ "$force" == "force" ]; then
  echo "" > /etc/systemd/system/docker.service.d/override.conf
fi

if [ $(cat /etc/systemd/system/docker.service.d/override.conf | grep "/dev/mapper/docker-thinpool" | wc -l) == 0  ]; then
  
  cat > /etc/systemd/system/docker.service.d/override.conf <<_EOF_

[Service]
ExecStart=
ExecStart=/usr/bin/docker daemon --storage-driver=devicemapper --storage-opt=dm.thinpooldev=/dev/mapper/docker-thinpool --storage-opt dm.use_deferred_removal=true --selinux-enabled --insecure-registry 172.30.0.0/16 $config

_EOF_

  systemctl daemon-reload

fi
}

function install_docker_legacy() {
  rm -rf /etc/systemd/system/docker.service.d/override.conf
  
  log "install docker"
    
  yum -y install docker

  setup_docker_storage
  
  sed -i '/OPTIONS=.*/c\OPTIONS="--selinux-enabled --insecure-registry 172.30.0.0/16 "' /etc/sysconfig/docker
        
  systemctl stop docker

  rm -rf /var/lib/docker

  /usr/bin/docker-storage-setup  
}


function install_docker_engine() {
  log "install docker-engine"  
  add_docker_repo
  yum -y install docker-engine
  systemctl enable docker.service
  systemctl start docker

  lvcreate --wipesignatures y -n thinpool docker -l ${percentage}%VG
  lvcreate --wipesignatures y -n thinpoolmeta docker -l 1%VG

  lvconvert -y --zero n -c 512K --thinpool docker/thinpool --poolmetadata docker/thinpoolmeta

  echo "activation {\n    thin_pool_autoextend_threshold=80\n    thin_pool_autoextend_percent=20\n}" > /etc/lvm/profile/docker-thinpool.profile

  lvchange --metadataprofile docker-thinpool docker/thinpool

  config_docker_options

  systemctl stop docker
  rm -rf /var/lib/docker

}

echo "-------------------------------------------------------------------------"
log "main loop ..."

if [ "$storage" == "" ]; then
  storage=/dev/sdb
fi  
if [ "$partition" == "" ]; then
  partition=1
fi

if [ "$remove" == "remove" ]; then
  remove_docker
  exit
fi

if [ "$config" != "" ]; then
  log "configure docker"
  echo "" > /etc/systemd/system/docker.service.d/override.conf
  config_docker_options
  systemctl daemon-reload
  systemctl restart docker
  docker info
  exit
fi


if [ $(lsblk | grep ${storage##*/} | wc -l) == 0 ]; then
  log "${storage} is not exist!"
  exit
fi

if [ $(vgdisplay | grep docker | wc -l) == 0 ] || [ "$all" == "all" ]; then
  
  log "setup direct disk mode"
  echo "-------------------------------------------------------------------------"
  if [ "$disk_is_ready" == "" ]; then
    format_disk $storage
  fi

  if [ "$partition" == "" ]; then
    partition=1
  fi

  yum -y update
  yum makecache
  remove_docker

  log "create pv and vg"
  pvcreate ${storage}${partition}
  vgcreate docker ${storage}${partition}

  if [ "$ver" == "1.10.3" ]; then
    log "trying to install docker legacy"
    install_docker_legacy
  else
    log "trying to install docker engine"
    install_docker_engine
  fi


  lvs -o+seg_monitor

fi # if [ $(vgdisplay | grep docker | wc -l) == 0 ]; then

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

