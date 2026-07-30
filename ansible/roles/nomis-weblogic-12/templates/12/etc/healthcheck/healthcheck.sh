#!/bin/bash

keepalive() {
   echo '<HTML><BODY>keepalive.htm on {{ weblogic_servername }}</BODY></HTML>'
}

while true
do
    output=$(/etc/init.d/weblogic-all healthcheck 2>&1)
    status=$?
    if [ $status -eq 1 ]
    then
        if [ -f "/u01/tag/static/keepalive.htm" ]
        then
            echo "${output}"
            /etc/init.d/weblogic-all status
            echo "Waiting 2 minutes before checking again"
            sleep 120
            output=$(/etc/init.d/weblogic-all healthcheck 2>&1)
            status=$?
            if [ $status -eq 1 ]
            then
                echo "${output}"
                /etc/init.d/weblogic-all status
                echo "Removing keepalive"
                rm -f /u01/tag/static/keepalive.htm
            fi
        fi
    else
        if [ ! -f "/u01/tag/static/keepalive.htm" ]
        then
            echo "${output}"
            echo "Creating keepalive /u01/tag/static/keepalive.htm"
            keepalive > /u01/tag/static/keepalive.htm
            chown oracle:oinstall /u01/tag/static/keepalive.htm
        fi
    fi
    sleep 120
done
