#!/bin/bash

source log.sh

log "switch to aliyun yum source"
#pushd /etc/yum.repos.d

#mv CentOS-Base.repo CentOS-Base.repo.bak
#wget -O CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
#yum clean all
#yum makecache

#popd

yum -y update

log "install zsh and oh-my-zsh"
yum -y install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

yum -y install net-tools.x86_64 redhat-lsb
yum -y install vim git ansible

log "installed common tools"
