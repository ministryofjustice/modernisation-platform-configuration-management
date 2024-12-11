#!/bin/bash
set -e
echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startNodeManager.sh"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startNodeManager.sh &
echo "Waiting for Secure socket listener started on port 5556"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh weblogic-node-manager "Secure socket listener started on port 5556"
