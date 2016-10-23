#!/bin/bash

source log.sh

log "switch to aliyun yum source"
pushd /etc/yum.repos.d

mv CentOS-Base.repo CentOS-Base.repo.bak
wget -O CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum makecache

popd

log "install zsh and oh-my-zsh"
yum install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

