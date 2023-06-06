#!/bin/bash

# Source function library.
. /etc/init.d/functions

keepalive() {
   echo '<HTML><BODY>keepalive.htm on {{ weblogic_servername }}</BODY></HTML>'
}

while true
do
    if ! service weblogic-all healthcheck > /dev/null; then
        echo "Removing keepalive" | logger -p local3.info -t "healthcheck"
        rm -f /u01/tag/static/keepalive.htm
    fi
    echo "Creating keepalive /u01/tag/static/keepalive.htm" | logger -p local3.info -t "healthcheck"
    keepalive > /u01/tag/static/keepalive.htm
    chown oracle:oinstall /u01/tag/static/keepalive.htm
    echo_success
    echo
    sleep 120
done