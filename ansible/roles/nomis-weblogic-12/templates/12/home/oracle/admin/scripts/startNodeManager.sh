#!/bin/bash
set -e
SERVER="weblogic.NodeManager"
export JAVA_OPTIONS="${JAVA_OPTIONS} -Djava.net.preferIPv4Stack=true"
export USER_MEM_ARGS="${USER_MEM_ARGS} -Djava.security.egd=file:/dev/./urandom"
export USER_MEM_ARGS="${USER_MEM_ARGS:-} {{ weblogic_common_jvm_args | join(' ') }}"

is_server_running() {
  pgrep -u oracle -f "$1" > /dev/null 2>&1
}

if is_server_running "$SERVER"; then
  echo "Node Manager is already running; skipping startup"
  exit 0
fi

echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startNodeManager.sh"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startNodeManager.sh &
echo "Waiting for Secure socket listener started on port 5556"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh weblogic-node-manager "Secure socket listener started on port 5556"
