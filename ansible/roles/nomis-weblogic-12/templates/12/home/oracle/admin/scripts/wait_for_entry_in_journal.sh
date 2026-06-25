#!/bin/bash
set -euo pipefail

service=$1
match_pattern=$2
timeout_secs=${3:-180}   # optional 3rd arg, default 180s

if [[ -z $match_pattern ]]; then
  echo "Usage $0 <service> <match_pattern> [timeout_seconds]" >&2
  exit 1
fi

if [[ ! -e "/etc/systemd/system/$service.service" ]]; then
   echo "$service not found" >&2
   exit 1
fi

if timeout "${timeout_secs}s" bash -c '
  journalctl -f -n0 -u "$1" | grep -m1 -qE "$2"
' _ "$service" "$match_pattern"; then
  exit 0
else
  exit_code=$?
  if [[ $exit_code -eq 124 ]]; then
    echo "Timed out after ${timeout_secs}s waiting for pattern '${match_pattern}' in ${service}" >&2
  fi
  exit $exit_code
fi