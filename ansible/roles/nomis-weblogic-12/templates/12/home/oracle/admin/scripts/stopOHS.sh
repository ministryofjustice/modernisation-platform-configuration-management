#!/bin/bash
set -euo pipefail

SERVER_PATTERN="httpd.*ohs1"
TIMEOUT_SECONDS=180

is_server_running() {
  pgrep -u oracle -f "$1" > /dev/null 2>&1
}

if ! is_server_running "$SERVER_PATTERN"; then
  echo "OHS is not running"
  exit 0
fi

echo "/u01/app/oracle/Middleware/oracle_common/common/bin/wlst.sh /home/oracle/admin/scripts/stopOHS.py"
/u01/app/oracle/Middleware/oracle_common/common/bin/wlst.sh /home/oracle/admin/scripts/stopOHS.py

echo "Waiting for weblogic-ohs to stop"

for i in $(seq 1 "$TIMEOUT_SECONDS"); do
  if ! is_server_running "$SERVER_PATTERN"; then
    echo "ohs1 has stopped"
    exit 0
  fi

  if (( i % 10 == 0 )); then
    echo "Still waiting for ohs1 to stop after ${i}s"
    pgrep -a -u oracle -f "$SERVER_PATTERN" || true
  fi

  sleep 1
done

echo "ERROR: Timed out waiting for ohs1 to stop"
pgrep -a -u oracle -f "$SERVER_PATTERN" || true
exit 1