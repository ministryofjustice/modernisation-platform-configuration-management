#!/bin/bash
service=$1
match_pattern=$2
if [[ -z $match_pattern ]]; then
  echo "Usage $0 <service> <match_pattern>" >&2
  exit 1
fi
if [[ ! -e "/etc/systemd/system/$service.service" ]]; then
   echo "$service not found" >&2
   exit 1
fi
# wait until a matching line found in the log file
# only way I could get this to work was to spawn tail in a subshell
( journalctl -f -n0 -u "$service" & ) | grep -qE "${match_pattern}"
# kill the tail subshell. It's not so easy to find the pid
pid=$(ps -o pid= -o cmd --forest -g $(ps -o sid= -p $$) | grep -F "journalctl -f -n0 -u $service" | grep -v grep | cut -d\  -f1)
[[ -n $pid ]] && kill $pid 2> /dev/null
exit 0
