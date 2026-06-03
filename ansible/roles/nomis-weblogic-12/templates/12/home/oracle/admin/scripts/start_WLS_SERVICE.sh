#!/bin/bash

DOMAIN_HOME=/u01/app/oracle/Middleware/user_projects/domains/nomis
SERVER=$1
PIDFILE=/tmp/$1.pid

export USER_MEM_ARGS="${USER_MEM_ARGS:-} {{ weblogic_common_jvm_args | join(' ') }}"

$DOMAIN_HOME/bin/startManagedWebLogic.sh $SERVER \
  > $DOMAIN_HOME/servers/$SERVER/logs/systemd-start.log 2>&1 &

sleep 10
pgrep -f "Dweblogic.Name=$SERVER" > "$PIDFILE"
exit 0