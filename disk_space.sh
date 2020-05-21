	#!/bin/bash
	#set -x
	
	#setting the variable to calculate space.
	space=`df -h | awk '{print $5}' | grep %| grep -v Use | sort -n | tail -1 | cut -d "%" -f1`
	
	#the below will show the details of the partition conusming high space.
	space1=`df -h | awk '{print $1,$5,$6}' | grep %| grep -v Use | sort -nk2 | tail -1`
	
	
	case $space in
	
	([0-9]|[1-4][0-9]| 50)
	    Message="The disk usage is normal $space % full \n
	    $space1" ;;
	(5[1-9]|6[0-9]|7[0-9]|80)
	    Message="The disk usage is going higher $space % full \n
	    $space1" ;;
	(8[1-9]|9[0-9]|100)
	    Message="The disk usage is higher and needs attention $space % full  \n
	    $space1" ;;
	esac
	
	`echo -e $Message | mail -s "Disk Usage alert" ${email_address}`


