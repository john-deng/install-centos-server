#!/bin/bash

source log.sh
source clap.sh

a=0

while [ $a -lt 10 ]
do
   log " install retry: $a "
   if [ $a -eq 8 ]
   then
      break
   fi

   ansible-playbook openshift-ansible/playbooks/byo/config.yml -v
   result=$?
   log "command returned: $result"

   if [ $result == 0 ]
   then
      break
   fi

   a=`expr $a + 1`
done


