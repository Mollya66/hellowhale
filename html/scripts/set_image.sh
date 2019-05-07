#! /bin/bash

# The script is to address kubectl timeout issue in Jenkins shell script in or after one build
# The root cause of the issue should be the limited CPU resource on this free EC2
# And workaround is to release resource by rebooting the EC2 and then run 'kubectl set deployment' to adopt the latest Docker image
# Cron job and run every minute

# To avoid running the script when build in Jenkins is in progress
javapid=`pgrep java`
pstree $javapid | grep +
if [ $? == 0 ]; then

	# Reboot is necessary to release resource after each build
    if [ ! -f /root/.markfile ];then
        touch /root/.markfile
    fi
	
    exit 1
	
fi

# Confirm if build completes by checking the number of Java processes of Jenkins
pstr=`pstree $javapid`
pstr=${pstr#*---}
pstr=${pstr%%\**}
if [[ $pstr -gt 43 ]];then

	# Exit if system uptime is less than 10mins since the cause of the higher number of Java processes may be that Jenkins is still starting
    upmin=`uptime -p |egrep -v 'hour|day'| grep min | awk '{print $2}'`
    if [[ ! -z $upmin && $upmin -lt 10 ]]; then
        exit
    fi

    if [ ! -f /root/.markfile ];then
        touch /root/.markfile
    fi
	
    exit 1
fi

if [ -f /root/.markfile ]; then
    rm /root/.markfile
    /usr/sbin/reboot
fi

ps -ef | grep kubectl | grep -v grep    > /dev/null
if [ $? == 0 ];then
    exit 1
fi

# Obtain the newest tag from the latest build
new_tag=`docker images mollya66/hellowhale | awk '$2 ~ /^[0-9]/ {print $2}' | sort -nr | sed -n '1p'`
kubectl get node
if [ $? != 0 ]; then
    exit 1
fi

# Obtain the image tag in current deployment
current_tag=`kubectl get deployments -o wide | awk '{print $7}'|sed -n '2p'|awk -F: '{print $2}'`
# Set new image if there is
if [ $new_tag -gt $current_tag ];then

    kubectl set image deployment hellowhale hellowhale=mollya66/hellowhale:$new_tag
    
fi
