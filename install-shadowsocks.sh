#!/bin/bash

source log.sh

log "install shadowsocks"
yum -y install python-setuptools
easy_install pip
pip install shadowsocks

log "install proxychains-ng"
git clone https://github.com/john-deng/proxychains-ng.git
yum -y install gcc g++
pushd proxychains-ng
make && make install
cp src/proxychains.conf /etc/
popd

log "installed shadowsocks"