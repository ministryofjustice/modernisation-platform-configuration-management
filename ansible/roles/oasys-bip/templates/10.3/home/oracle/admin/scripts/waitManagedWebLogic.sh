#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'wait_for_entry_in_log.sh wls_managedserver.service "Server started in RUNNING mode" "startManagedWebLogic.sh"'
  {{ scripts_dir }}/wait_for_entry_in_log.sh wls_managedserver.service "Server started in RUNNING mode" "startManagedWebLogic.sh"
  exitcode=$?
  echo "Waited: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  return 1
fi
