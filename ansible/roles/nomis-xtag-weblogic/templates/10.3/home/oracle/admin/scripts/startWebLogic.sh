#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  su - oracle -c /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/startWebLogic.sh
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo -n "must be run as root"
  exit 1
fi
