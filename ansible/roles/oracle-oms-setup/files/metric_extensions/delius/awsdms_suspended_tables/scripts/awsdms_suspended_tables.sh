#!/bin/bash
#
#  Get Suspended AWS DMS Tables
#

. ~/.bash_profile

if [[ $(srvctl config database -d ${ORACLE_SID} | awk -F: '/Start options/{print $2}' | tr -d ' ') == mount ]];
then
   # Ignore this metric on mounted (not open) databases
   exit 0
fi

# Check if the AWS DMS Suspend Table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "/ as sysdba" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='DELIUS_AUDIT_DMS_POOL' AND table_name = 'awsdms_suspended_tables';
EXIT;
EOF
)

# Trim any leading/trailing whitespace.
table_exists=$(echo "$table_exists" | xargs)

# If the count is zero, the table does not exist.  Do not treat this as an error
# as this table will only exist if the database is configured as a DMS client.
if [ "$table_exists" -eq 0 ]; then
    exit 0
fi


sqlplus -s /nolog <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SET LINES 512
connect / as sysdba
SELECT
"table_owner"||'|'||"table_name"||'|'||
"task_name"||'|'||"server_name"||'|'||
'AWS DMS Replication of '||"table_owner"||'.'||"table_name"||' by '||"task_name"||' on '||"server_name"||' suspended'||
CASE WHEN "suspend_reason" IS NOT NULL THEN ' due to '||"suspend_reason" ELSE NULL END ||
CASE WHEN "suspend_timestamp" IS NOT NULL THEN ' since '||CAST("suspend_timestamp" AS VARCHAR2(20)) ELSE NULL END
FROM
   delius_audit_dms_pool."awsdms_suspended_tables";
EXIT
EOSQL