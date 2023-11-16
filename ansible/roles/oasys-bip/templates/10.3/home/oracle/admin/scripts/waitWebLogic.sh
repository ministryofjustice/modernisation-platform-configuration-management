#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'wait_for_entry_in_log.sh wls_adminserver.service "Server started in RUNNING mode" "startWebLogic.sh"'
  {{ scripts_dir }}/wait_for_entry_in_log.sh wls_adminserver.service "Server started in RUNNING mode" "startWebLogic.sh"
  exitcode=$?
  echo "Waited: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  return 1
fi
