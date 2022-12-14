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
if [[ -z $filter_pattern ]]; then  
  tail -f -n0 "$logfile" | grep -qE "${match_pattern}"
else
  tail -f -n0 "$logfile" | grep -qE "${filter_pattern}(.*)${match_pattern}"
fi
