#!/bin/bash
if [[ $(whoami) == "root" ]]; then
  echo 'su - oracle -c {{ domain_home }}/{{ domain_name }}/bin/startWebLogic.sh'
  su - oracle -c {{ domain_home }}/{{ domain_name }}/bin/startWebLogic.sh
  exitcode=$?
  echo "Started: exitcode=$exitcode"
  exit $exitcode
else
  echo "must be run as root"
  exit 1
fi
