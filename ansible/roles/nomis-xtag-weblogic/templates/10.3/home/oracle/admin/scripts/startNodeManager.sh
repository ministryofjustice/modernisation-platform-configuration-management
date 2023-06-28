#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'su - oracle -c /u01/app/oracle/Middleware/wlserver_10.3/server/bin/startNodeManager.sh'
  su - oracle -c /u01/app/oracle/Middleware/wlserver_10.3/server/bin/startNodeManager.sh
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  exit 1
fi
