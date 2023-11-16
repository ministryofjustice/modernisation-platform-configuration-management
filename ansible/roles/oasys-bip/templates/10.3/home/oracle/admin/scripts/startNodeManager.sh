#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'su - oracle -c {{ wl_home }}/server/bin/startNodeManager.sh'
  su - oracle -c {{ wl_home }}/server/bin/startNodeManager.sh
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  exit 1
fi
