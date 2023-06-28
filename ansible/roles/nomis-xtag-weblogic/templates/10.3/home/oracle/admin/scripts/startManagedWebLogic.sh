#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'su - oracle -c ". /u01/app/oracle/Middleware/wlserver_10.3/server/bin/setWLSEnv.sh && . /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh && /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/startManagedWebLogic.sh {{ managed_server }}"'
  su - oracle -c ". /u01/app/oracle/Middleware/wlserver_10.3/server/bin/setWLSEnv.sh && . /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh && /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/startManagedWebLogic.sh {{ managed_server }}"
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  exit 1
fi
