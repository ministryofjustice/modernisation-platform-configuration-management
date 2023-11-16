#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'wait_for_entry_in_log.sh wls_nodemanager.service "listener started" "startNodeManager.sh"'
  {{ scripts_dir }}/wait_for_entry_in_log.sh wls_nodemanager.service "listener started" "startNodeManager.sh"
  exitcode=$?
  echo "Waited: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  return 1
fi
