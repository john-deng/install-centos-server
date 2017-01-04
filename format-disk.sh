#!/bin/bash

function format_disk() {

storage=$1

fdisk ${storage} <<EOF
d

n
p
1



t
8e

w
EOF

}

