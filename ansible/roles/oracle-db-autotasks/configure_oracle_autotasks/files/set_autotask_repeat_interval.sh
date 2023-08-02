#!/bin/bash

export ORACLE_SID=$1
export WINDOW_NAME=$2
export REPEAT_INTERVAL=$3

# Check Oracle SID exists
/usr/local/bin/dbhome ${ORACLE_SID}
if [[ $? -gt 0 ]]
then
echo "Invalid Oracle SID"
exit 123
fi

echo "Setting ${WINDOW_NAME} Repeat Interval to ${REPEAT_INTERVAL}"

export PATH=$PATH:/usr/local/bin; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

sqlplus -s /  as sysdba <<EOF
SET FEEDBACK ON
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE('sys.${WINDOW_NAME}', 'repeat_interval','${REPEAT_INTERVAL}');
EXIT
EOF