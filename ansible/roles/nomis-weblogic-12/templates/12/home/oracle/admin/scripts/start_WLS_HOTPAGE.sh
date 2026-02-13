#!/bin/bash

DOMAIN_HOME=/u01/app/oracle/Middleware/user_projects/domains/nomis
SERVER=WLS_HOTPAGE
PIDFILE=/tmp/WLS_HOTPAGE.pid

$DOMAIN_HOME/bin/startManagedWebLogic.sh $SERVER \
  > $DOMAIN_HOME/servers/$SERVER/logs/systemd-start.log 2>&1 &

sleep 10
pgrep -f "Dweblogic.Name=$SERVER" > "$PIDFILE"
exit 0