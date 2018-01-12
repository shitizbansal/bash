#!/bin/bash

#This will check the memory and restart the 

available_mem=`free -m | awk {'print $7'} | sed -n '2p'`
echo "available memory: $available_mem"

# Check if the memory if below 1300
if [[ $available_mem < 1300 ]]; then

#Restart the openshift master service  
                sudo systemctl restart atomic-openshift-master.service

#Log the same in the  /var/mail/cloud-user                
                echo 'memory cleanup executed'
fi

