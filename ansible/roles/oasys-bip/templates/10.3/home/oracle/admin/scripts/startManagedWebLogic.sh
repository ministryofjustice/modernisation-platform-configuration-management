#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'su - oracle -c ". {{ wl_home }}/server/bin/setWLSEnv.sh && {{ domain_home }}/{{ domain_name }}/bin/startManagedWebLogic.sh {{ managed_server }}"'
  su - oracle -c ". {{ wl_home }}/server/bin/setWLSEnv.sh && {{ domain_home }}/{{ domain_name }}/bin/startManagedWebLogic.sh {{ managed_server }}"
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  exit 1
fi