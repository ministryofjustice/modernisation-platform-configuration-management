#!/bin/bash
#
# Calculate the maximum number of minutes an alfresco
# message has been waiting to be processed.

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SELECT ROUND(COALESCE(MAX(SYSDATE-date_created),0)*24*60,1) unprocessed_mins_ago
FROM   delius_app_schema.spg_notification
WHERE  processed_flag=4
;
EXIT
EOSQL