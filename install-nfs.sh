#!/bin/bash
###############################################################################
# Description: nfs installer for centos
# Author: John Deng (john.deng@qq.com)
###############################################################################
source "log.sh"
source "clap.sh"
source "format-disk.sh"

if [ "$help" == "help" ]; then
  log "please specify storage, e.g. ./install-nfs.sh storage=/dev/sdc size=100G fs=xfs vg=nfs lv=exports"
  log "optional arguments: has_vg fs=xfs vg=nfs lv=exports "
  exit
fi

log "validating user inputs"
if [ "$fs" == "" ]; then
  fs=xfs
fi

if [ "$vg" == "" ]; then
  vg=nfs
fi

if [ "$lv" == "" ]; then
  lv=exports
fi

if [ "$size" == "" ]; then
  log "please specify storage size"
  exit
fi

if [ "$partition" == "" ]; then
    partition=1
fi

nfs_dev=/dev/mapper/$vg-$lv

log "remove lvm settings"
lvremove -f $nfs_dev 
vgremove -f $vg
if [ "$disk_is_ready" == "" ]; then
  log "formating disk"
  format_disk $storage
fi

pvcreate ${storage}${partition}
vgcreate $vg ${storage}${partition}

lvm_pool=${lv}
lvcreate -n $lvm_pool -L $size $vg
log "check if lvm pool is created"
if [ $(lvs | grep $lvm_pool | wc -l) == 0 ]; then
  log "$lvm_pool does not exist."
  exit
fi
if [ "$nfs_dir" == "" ]; then
  nfs_dir=/$lv
fi

log "make file system to $fs, it may take a while, please be patient"
date
mkfs.$fs $nfs_dev
date
log "file system is formatd to $fs"

log "mount nfs volume"
mkdir -p $nfs_dir
chmod 777 $nfs_dir
mount $nfs_dev $nfs_dir

if [ $(df -h | grep $nfs_dev | wc -l) == 0 ]; then
  log "failed to mount disk $nfs_dev"
  exit
fi

if [ $(cat /etc/fstab | grep $nfs_dev | wc -l) == 0 ]; then 
  cat >> /etc/fstab <<_EOF_
$nfs_dev $nfs_dir           $fs    defaults        0 0
_EOF_

fi

log "Install the file-server package group"
yum groupinstall -y file-server

log "Add a new service to the firewall"
systemctl enable firewalld.service
systemctl start firewalld
firewall-cmd --permanent --add-service=nfs
./open-firewall.sh port=111
./open-firewall.sh port=2049

log "Reload the firewall configuration"
firewall-cmd --reload

log "Activate the NFS services at boot"
systemctl enable rpcbind nfs-server

log "Start the NFS services"
systemctl start rpcbind nfs-server

log "Assign the correct SELinux contexts to the new directories"
yum install -y setroubleshoot-server
semanage fcontext -a -t public_content_rw_t "$nfs_dir"
restorecon -R $nfs_dir

semanage boolean -l | egrep "nfs|SELinux"
setsebool -P nfs_export_all_rw on
setsebool -P nfs_export_all_ro on
setsebool -P use_nfs_home_dirs on

cat > /etc/exports <<_EOF_
$nfs_dir *(rw,no_root_squash)
_EOF_

log "Restrat nfs server"
systemctl restart nfs-server

log "check if nfs is avaible"
if [ $(showmount -e localhost | grep $nfs_dir | wc -l) == 0 ]; then
  log "failed to install nfs server!"
fi

log "nfs server is installed and it is ready to use."

