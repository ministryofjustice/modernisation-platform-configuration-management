#!/bin/bash

get_process_pids() {
  process_pids1=$(pgrep -u oracle -f "startWebLogic.sh$" 2> /dev/null)
  [[ -z $process_pids1  ]] && return 1
  (
    for process_pid in $process_pids1; do
      pstree -ap "$process_pid" | grep -v '{' | cut -d, -f2 | cut -d\  -f1
    done
  ) | sort -u | tr '\n' ' '
}

stop_process() {
  if ! PIDS=$(get_process_pids); then
    echo "already stopped"
    return 0
  fi

  timeout 60 {{ domain_home }}/{{ domain_name }}/bin/stopWebLogic.sh 

  if ! PIDS=$(get_process_pids); then
    echo "stopped"
    return 0
  fi

  echo "kill $PIDS" 
  kill $PIDS
  sleep 2

  if ! get_process_pids > /dev/null; then
    echo "stopped"
    return 0
  fi
  
  sleep 5
  if ! PIDS=$(get_process_pids); then
    echo "stopped after 5 seconds"
    return 0
  fi

  echo "kill -9 $PIDS"
  kill -9 $PIDS
  sleep 2

  if ! PIDS=$(get_process_pids); then
    echo "stopped after kill -9"
    return 0
  fi
  echo "could not kill $PIDS"
  return 1
}

stop_process
