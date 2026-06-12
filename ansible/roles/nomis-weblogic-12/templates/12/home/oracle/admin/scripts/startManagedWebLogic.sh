#!/bin/bash
set -e
SERVER="$1"
export USER_MEM_ARGS="${USER_MEM_ARGS:-} {{ weblogic_common_jvm_args | join(' ') }}"

is_server_running() {
  pgrep -u oracle -f "weblogic.Name=$SERVER " > /dev/null 2>&1
}

if is_server_running "$SERVER"; then
  echo "$SERVER is already running; skipping startup"
  exit 0
fi

echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startManagedWebLogic.sh $SERVER"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startManagedWebLogic.sh "$SERVER" &
echo "Waiting for RUNNING"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh "$SERVER" RUNNING
