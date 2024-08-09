#!/bin/bash
#
# Calculate the maximum number of minutes an alfresco
# message has been waiting to be processed.
#
# 0: Initial State, Awaiting Processing (Allow 60 mins in this state)
# 4: Picked for Processing (Allow 5 mins in this state)

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SELECT   processed_flag||'|'||ROUND(COALESCE(MAX(SYSDATE-date_created),0)*24*60,1) mins_in_state
FROM     delius_app_schema.spg_notification
WHERE    processed_flag IN (0,4)
GROUP BY processed_flag;
EXIT
EOSQL