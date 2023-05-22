#!/bin/bash
logfile=$1
match_pattern=$2
filter_pattern=$3
if [[ -z $match_pattern ]]; then
  echo "Usage $0 <logfile> <match_pattern> [<filter_pattern>]" >&2
  exit 1
fi
if [[ ! -e "$logfile" ]]; then
   echo "$logfile not found" >&2
   exit 1
fi
# wait until a matching line found in the log file
# only way I could get this to work was to spawn tail in a subshell
if [[ -z $filter_pattern ]]; then
  ( tail -f -n0 "$logfile" & ) | grep -qE "${match_pattern}"
else
  ( tail -f -n0 "$logfile" & ) | grep -qE "${filter_pattern}(.*)${match_pattern}"
fi
# kill the tail subshell. It's not so easy to find the pid
pid=$(ps -o pid= -o cmd --forest -g $(ps -o sid= -p $$) | grep -F "tail -f -n0 $logfile" | grep -v grep | cut -d\  -f1)
[[ -n $pid ]] && kill $pid 2> /dev/null
exit 0
