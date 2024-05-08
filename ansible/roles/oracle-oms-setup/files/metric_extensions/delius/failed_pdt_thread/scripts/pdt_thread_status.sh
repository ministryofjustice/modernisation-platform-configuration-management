#!/bin/bash
#
#  Get status code for PRF threads (2=failed)
#

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SELECT component_id||'|'||thread_id||'|'||status
FROM delius_app_schema.pdt_thread 
WHERE component_id BETWEEN 500 AND 505   -- Performance Monitoring Threads
OR         component_id BETWEEN 100 AND 107   -- Alfresco Message Queue Threads
ORDER BY component_id, thread_id;
EXIT
EOSQL