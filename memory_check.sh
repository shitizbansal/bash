#!/bin/bash

free_mem=`free -m | awk {'print $6'} | grep -v available | head -n 1`

if [[ free_mem < 1024 ]]; then

        sudo systemctl restart atomic-openshift-master.service
fi

