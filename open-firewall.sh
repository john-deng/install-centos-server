#!/bin/bash

systemctl unmask firewalld
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --zone=public --add-port=52055/tcp --permanen
firewall-cmd --reload
