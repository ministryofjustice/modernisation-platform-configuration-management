#!/bin/bash

export ORACLE_SID=$1

# Check Oracle SID exists
/usr/local/bin/dbhome ${ORACLE_SID} >/dev/null
if [[ $? -gt 0 ]]
then
echo "Invalid Oracle SID"
exit 123
fi

export PATH=$PATH:/usr/local/bin; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

# Get the window duration in minutes (disregard any seconds component)
sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT window_name||','||
       repeat_interval||','||
       ((extract(day from duration)*60*24)+(extract(hour from duration)*60)+(extract(minute from duration)))
FROM   dba_scheduler_windows;
EXIT
EOF