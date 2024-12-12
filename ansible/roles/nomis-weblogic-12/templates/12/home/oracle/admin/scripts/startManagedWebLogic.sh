#!/bin/bash
set -e
echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startManagedWebLogic.sh $1"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startManagedWebLogic.sh $1 &
echo "Waiting for RUNNING"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh $1 RUNNING
