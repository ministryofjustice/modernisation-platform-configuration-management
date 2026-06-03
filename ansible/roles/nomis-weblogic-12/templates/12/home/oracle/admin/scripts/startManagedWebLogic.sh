#!/bin/bash
set -e

export USER_MEM_ARGS="${USER_MEM_ARGS:-} {{ weblogic_common_jvm_args | join(' ') }}"

echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startManagedWebLogic.sh $1"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startManagedWebLogic.sh "$1" &
echo "Waiting for RUNNING"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh "$1" RUNNING
