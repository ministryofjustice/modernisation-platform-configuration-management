#!/bin/bash

keepalive() {
   echo '<HTML><BODY>keepalive.htm on {{ weblogic_servername }}</BODY></HTML>'
}

while true
do
    /etc/init.d/weblogic-all healthcheck > /dev/null 2>&1
    status=$?
    echo "logging: $status" | logger -p local3.info -t "healthcheck"
    if [ $status -eq 1 ]
    then
        echo "Removing keepalive" | logger -p local3.info -t "healthcheck"
        rm -f /u01/tag/static/keepalive.htm
    else
        echo "Creating keepalive /u01/tag/static/keepalive.htm" | logger -p local3.info -t "healthcheck"
        keepalive > /u01/tag/static/keepalive.htm
        chown oracle:oinstall /u01/tag/static/keepalive.htm
        echo
    fi
    sleep 30
done