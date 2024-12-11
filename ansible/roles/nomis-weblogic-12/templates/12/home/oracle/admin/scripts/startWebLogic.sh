#!/bin/bash
set -e
echo "Starting: /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startWebLogic.sh"
/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startWebLogic.sh &
PID=$!
echo "Waiting: /home/oracle/admin/scripts/wait_for_entry_in_log.sh weblogic-server RUNNING startWebLogic.sh"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh weblogic-server RUNNING
echo "Sending notify --ready"
systemd-notify --ready
echo "Wait: PID=$PID"
wait $PID
