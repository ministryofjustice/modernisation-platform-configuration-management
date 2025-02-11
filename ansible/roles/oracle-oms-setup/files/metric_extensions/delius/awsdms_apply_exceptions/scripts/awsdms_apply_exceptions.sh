#!/bin/bash
#
#  Get Recent AWS DMS Apply Exceptions
#

. ~/.bash_profile

if [[ $(srvctl config database -d ${ORACLE_SID} | awk -F: '/Start options/{print $2}' | tr -d ' ') == mount ]];
then
    # Ignore this metric on mounted (not open) databases
    exit 0
fi

# Check if the AWS DMS Apply Exceptions Table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "/ as sysdba" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='DELIUS_AUDIT_DMS_POOL' AND table_name = 'awsdms_apply_exceptions';
EXIT;
EOF
)

# Trim any leading/trailing whitespace.
table_exists=$(echo "$table_exists" | xargs)

# If the count is zero, the table does not exist.  Do not treat this as an error
# as it may be intentional.
if [ "$table_exists" -eq 0 ]; then
    exit 0
fi

# First column is total number of errors in past 24 hours
# Second column is total number of errors (to encourage housekeeping of the table)
sqlplus -s /nolog <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SET LINES 512
connect / as sysdba
SELECT
COALESCE
    SUM(
        CASE
            WHEN error_time > sysdate - 1 THEN
                1
            ELSE
                0
        END
    ),0)
    || '|'
    || COUNT(*)
FROM
    delius_audit_dms_pool."awsdms_apply_exceptions";
EXIT
EOSQL