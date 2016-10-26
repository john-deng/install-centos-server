#!/bin/bash

if [ -f /var/run/shadowsocks.pid ]; then
    sslocal -c ss/shadowsocks.json -d stop
fi

sslocal -c ss/shadowsocks.json -d start
