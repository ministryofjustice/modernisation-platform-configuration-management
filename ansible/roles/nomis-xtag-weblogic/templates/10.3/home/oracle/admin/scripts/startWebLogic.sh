#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'su - oracle -c /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/startWebLogic.sh'
  su - oracle -c /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/startWebLogic.sh
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  exit 1
fi
