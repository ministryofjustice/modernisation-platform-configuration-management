#!/bin/bash

get_process_pids() {
  process_pids1=$(pgrep -u oracle -f "startWebLogic.sh([[:space:]]|$)" 2>/dev/null)
  process_pids2=$(pgrep -u oracle -f "([[:space:]]|-)D?weblogic.Name=AdminServer([[:space:]]|$)" 2>/dev/null)
  [[ -z $process_pids1 && -z $process_pids2 ]] && return 1
  (
    for process_pid in $process_pids1 $process_pids2; do
      pstree -ap "$process_pid" | grep -v '{' | cut -d, -f2 | cut -d\  -f1
    done
  ) | sort -u | tr '\n' ' '
}

stop_process() {
  echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/stopWebLogic.sh $1"
  /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/stopWebLogic.sh "$1" || true

  if ! PIDS=$(get_process_pids); then
    return 0
  fi

  echo "kill $PIDS"
  kill $PIDS
  sleep 2

  if ! PIDS=$(get_process_pids); then
    return 0
  fi
  sleep 5
  if ! PIDS=$(get_process_pids); then
    return 0
  fi

  echo "kill -9 $PIDS"
  kill -9 $PIDS
}

stop_process
