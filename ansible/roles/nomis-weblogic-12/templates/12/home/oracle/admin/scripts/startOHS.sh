#!/bin/bash
set -e
SERVER="httpd"
SERVICE="weblogic-ohs"
export JAVA_OPTIONS="${JAVA_OPTIONS} -Djava.net.preferIPv4Stack=true"
export USER_MEM_ARGS="${USER_MEM_ARGS} -Djava.security.egd=file:/dev/./urandom"
export USER_MEM_ARGS="${USER_MEM_ARGS:-} {{ weblogic_common_jvm_args | join(' ') }}"

is_server_running() {
  pgrep -u oracle -f "$1" > /dev/null 2>&1
}

if is_server_running "$SERVER"; then
  echo "OHS is already running; skipping startup"
  exit 0
fi

echo "/u01/app/oracle/Middleware/oracle_common/common/bin/wlst.sh /home/oracle/admin/scripts/startOHS.py"
nohup /u01/app/oracle/Middleware/oracle_common/common/bin/wlst.sh /home/oracle/admin/scripts/startOHS.py &

echo "Waiting for $SERVICE to start"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh "$SERVICE" "Successfully started server ohs1" 60
