#!/bin/bash
set -e
echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startWebLogic.sh"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startWebLogic.sh &
echo "Waiting for RUNNING"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh weblogic-server RUNNING
